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
import tidal_ai_playlist/internal/openai/api as openai_api
import tidal_ai_playlist/internal/openai/config as openai_config
import tidal_ai_playlist/internal/openai/types as openai_types
import tidal_ai_playlist/internal/playlist_parser
import tidal_ai_playlist/internal/tidal/api as tidal_api
import tidal_ai_playlist/internal/tidal/config as tidal_config
import tidal_ai_playlist/internal/tidal/types as tidal_types
import tidal_ai_playlist/internal/types

const instructions = "You are a music recommendation assistant.

Given the user's input, create a playlist as instructed. Include only artist and song title, tab-separated (TSV format).

Do not include markdown, commentary, or explanations.
Wrap the playlist between exactly these separator lines:
=====
(playlist)
====="

pub fn main() -> Nil {
  //create_playlist()
  start(option.None)
}

pub fn start(config: option.Option(config.Config)) {
  let assert Ok(playlist) = interactive_playlist(config)
  Nil
}

fn load_tidal_config() -> Result(tidal_types.Config, errors.TidalAPIError) {
  let filepath_result = envoy.get("TIDAL_AI_PLAYLIST_CONFIG")

  use config <- result.try(case filepath_result {
    Ok(filepath) -> {
      io.println("LOOKING FOR FILEPATH")
      case tidal_config.from_file(filepath) {
        Ok(config) -> Ok(config)
        Error(_) -> {
          io.println("ERRRO")
          tidal_config.from_env()
        }
      }
    }
    Error(Nil) -> tidal_config.from_env()
  })

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

pub fn interactive_playlist(
  config: option.Option(config.Config),
) -> Result(Nil, errors.TidalAPIError) {
  use config <- result.try(case config {
    option.Some(config) -> Ok(config)
    option.None -> default_config()
  })
  io.println("What music would you like to listen to today?")
  let assert Ok(first_prompt) = input.input(prompt: "> ")

  use playlist <- result.try(
    interactive_loop(config, [openai_types.ResponsesInput("user", first_prompt)]),
  )
  create_tidal_playlist_from_openai(config, playlist)
}

fn default_config() -> Result(config.Config, errors.TidalAPIError) {
  use openai_config <- result.try(openai_config.from_env(instructions))
  use tidal_config <- result.try(load_tidal_config())
  Ok(config.Config(openai_config: openai_config, tidal_config: tidal_config))
}

fn interactive_loop(
  config: config.Config,
  messages: List(openai_types.ResponsesInput),
) -> Result(types.Playlist, errors.TidalAPIError) {
  case openai_api.ask(messages, config.openai_config) {
    Ok(reply) -> {
      io.println("\nProposed Playlist:\n")
      io.println(reply)

      io.println("\nGenerate this playlist? (y/n)")
      let assert Ok(ans) = input.input(prompt: "> ")
      let trimmed = string.trim(ans)

      case trimmed {
        "y" -> {
          io.println("What would you like to name the playlist?")
          let assert Ok(title) = input.input(prompt: "> ")
          io.println("What would you like to set for the description?")
          let assert Ok(description) = input.input(prompt: "> ")

          let songs = playlist_parser.parse(reply)
          Ok(types.Playlist(
            songs: songs,
            title: title,
            description: description,
          ))
        }

        _ -> {
          io.println("What would you like changed?")
          let assert Ok(new_prompt) = input.input(prompt: "> ")
          let new_messages =
            list.append(messages, [
              openai_types.ResponsesInput("assistant", reply),
              openai_types.ResponsesInput("user", new_prompt),
            ])
          interactive_loop(config, new_messages)
        }
      }
    }

    Error(reason) -> {
      io.println("Error: ")
      Error(reason)
    }
  }
}

pub fn create_tidal_playlist_from_openai(
  config: config.Config,
  playlist: types.Playlist,
) -> Result(Nil, errors.TidalAPIError) {
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
          Error(Nil)
        }
      }
    })
  list.map(track_ids, fn(x) { io.println(int.to_string(x)) })

  use _ <- result.try(tidal_api.add_tracks_to_playlist(
    tidal_config,
    new_playlist.id,
    track_ids,
    new_playlist.etag,
  ))

  Ok(Nil)
}
