import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string

import envoy
import input

import tidal_ai_playlist/internal/config
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/openai/api as openai_api
import tidal_ai_playlist/internal/openai/config as openai_config
import tidal_ai_playlist/internal/openai/types as openai_types
import tidal_ai_playlist/internal/playlist_parser
import tidal_ai_playlist/internal/tidal/api as tidal_api
import tidal_ai_playlist/internal/tidal/config as tidal_config
import tidal_ai_playlist/internal/tidal/types as tidal_types
import tidal_ai_playlist/internal/types

const prompt = "> "

const instructions = "You are a music recommendation assistant.

Given the user's input, create a playlist as instructed. Include only artist and song title, tab-separated (TSV format).

Do not include markdown, commentary, or explanations.
Wrap the playlist between exactly these separator lines:
=====
(playlist)
====="

pub type Dependencies {
  Dependencies(
    get_env_fn: fn(String) -> Result(String, Nil),
    output_fn: fn(String) -> Nil,
    http_client: http.Client,
    input_fn: fn(String) -> Result(String, Nil),
  )
}

pub fn main() -> Nil {
  let dependencies =
    Dependencies(
      get_env_fn: envoy.get,
      output_fn: io.println,
      http_client: http.default_client,
      input_fn: input.input,
    )
  let assert Ok(_) = run(dependencies)
  Nil
}

fn load_tidal_config(
  dependencies: Dependencies,
) -> Result(tidal_types.Config, errors.TidalAIPlaylistError) {
  let filepath_result = dependencies.get_env_fn("TIDAL_AI_PLAYLIST_CONFIG")

  use config <- result.try(case filepath_result {
    Ok(filepath) -> {
      case tidal_config.from_file(filepath) {
        Ok(config) -> Ok(config)
        Error(_) -> {
          tidal_config.from_env(dependencies.get_env_fn)
        }
      }
    }
    Error(Nil) -> tidal_config.from_env(dependencies.get_env_fn)
  })

  let config =
    config
    |> tidal_config.add_http_client(dependencies.http_client)
    |> tidal_config.add_output_fn(dependencies.output_fn)

  use #(refresh_token, user_id) <- result.try(
    case config.refresh_token, config.user_id {
      option.Some(refresh_token), option.Some(user_id) ->
        Ok(#(refresh_token, user_id))
      _, _ ->
        case tidal_api.login(config) {
          Ok(oauth_token) ->
            Ok(#(oauth_token.refresh_token, oauth_token.user_id))
          Error(err) -> Error(err)
        }
    },
  )

  let config =
    config
    |> tidal_config.add_refresh_token(refresh_token)
    |> tidal_config.add_user_id(user_id)

  use access_token_response <- result.try(tidal_api.refresh_token(config))

  let config =
    config
    |> tidal_config.add_access_token(access_token_response.access_token)
    |> tidal_config.add_user_id(access_token_response.user_id)

  case filepath_result {
    Ok(filepath) -> tidal_config.to_file(config, filepath)
    _ -> Ok(config)
  }
}

pub fn run(
  dependencies: Dependencies,
) -> Result(types.Playlist, errors.TidalAIPlaylistError) {
  use config <- result.try(default_config(dependencies))

  let assert Ok(first_prompt) =
    ask_user(dependencies, "What music would you like to listen to today?")

  use playlist <- result.try(interactive_loop(
    config,
    [openai_types.ResponsesInput("user", first_prompt)],
    0,
    dependencies,
  ))
  create_tidal_playlist_from_openai(config, playlist, dependencies)
}

fn default_config(
  dependencies: Dependencies,
) -> Result(config.Config, errors.TidalAIPlaylistError) {
  use openai_built_config <- result.try(openai_config.from_env(
    instructions,
    dependencies.get_env_fn,
  ))
  use tidal_config <- result.try(load_tidal_config(dependencies))
  Ok(config.Config(
    openai_config: openai_built_config
      |> openai_config.add_http_client(dependencies.http_client),
    tidal_config: tidal_config,
  ))
}

fn max_number_of_retries(
  retries: Int,
) -> Result(types.Playlist, errors.TidalAIPlaylistError) {
  case retries {
    3 -> Error(errors.MaxNumberOfOpenAIRetries)
    _ -> Ok(types.Playlist(songs: [], title: "", description: ""))
  }
}

fn ask_user(dependencies: Dependencies, question) -> Result(String, Nil) {
  dependencies.output_fn(question)
  dependencies.input_fn(prompt)
}

fn interactive_loop(
  config: config.Config,
  messages: List(openai_types.ResponsesInput),
  retries: Int,
  dependencies: Dependencies,
) -> Result(types.Playlist, errors.TidalAIPlaylistError) {
  use _ <- result.try(max_number_of_retries(retries))
  case openai_api.ask(messages, config.openai_config) {
    Ok(reply) -> {
      let songs =
        playlist_parser.parse(reply)
        |> list.filter(fn(r) {
          case r {
            types.Track(_, _) -> True
          }
        })

      case list.is_empty(songs) {
        True -> {
          dependencies.output_fn(
            "No songs could be parsed. Asking AI to correct the format...",
          )
          let new_messages =
            list.append(messages, [
              openai_types.ResponsesInput("assistant", reply),
              openai_types.ResponsesInput(
                "user",
                "Please resend the playlist in the correct TSV format: Artist<TAB>Title per line",
              ),
            ])
          interactive_loop(config, new_messages, retries + 1, dependencies)
        }

        False -> {
          dependencies.output_fn("\nProposed Playlist:\n")
          list.map(songs, fn(song) {
            dependencies.output_fn(song.artist <> "\t" <> song.title)
          })

          dependencies.output_fn("\nGenerate this playlist? (y/n)")
          let assert Ok(ans) =
            ask_user(dependencies, "\nGenerate this playlist? (y/n)")
          let trimmed = string.trim(ans)

          case trimmed {
            "y" -> {
              let assert Ok(title) =
                ask_user(
                  dependencies,
                  "What would you like to name the playlist?",
                )
              let assert Ok(description) =
                ask_user(
                  dependencies,
                  "What would you like to set for the description?",
                )

              Ok(types.Playlist(
                songs: songs,
                title: title,
                description: description,
              ))
            }

            _ -> {
              let assert Ok(new_prompt) =
                ask_user(dependencies, "What would you like changed?")
              let new_messages =
                list.append(messages, [
                  openai_types.ResponsesInput("assistant", reply),
                  openai_types.ResponsesInput("user", new_prompt),
                ])
              interactive_loop(config, new_messages, 0, dependencies)
            }
          }
        }
      }
    }

    Error(reason) -> {
      dependencies.output_fn("Error: ")
      Error(reason)
    }
  }
}

pub fn create_tidal_playlist_from_openai(
  config: config.Config,
  playlist: types.Playlist,
  dependencies: Dependencies,
) -> Result(types.Playlist, errors.TidalAIPlaylistError) {
  let tidal_config = config.tidal_config
  use new_playlist <- result.try(tidal_api.create_playlist(
    tidal_config,
    playlist.title,
    playlist.description,
  ))

  let track_ids =
    playlist.songs
    |> list.map(fn(song) {
      result.map(
        tidal_api.search_track(tidal_config, song.artist, song.title),
        fn(track) { track.id },
      )
    })
    |> list.filter_map(fn(r) {
      case r {
        Ok(id) -> Ok(id)
        Error(err) -> {
          Error(err)
        }
      }
    })
  list.map(track_ids, fn(x) { dependencies.output_fn(int.to_string(x)) })

  use _ <- result.try(tidal_api.add_tracks_to_playlist(
    tidal_config,
    new_playlist.id,
    track_ids,
    new_playlist.etag,
  ))

  Ok(playlist)
}
