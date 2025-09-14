import gleam/list
import gleam/string

import tidal_ai_playlist/internal/config
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/openai/api as openai_api
import tidal_ai_playlist/internal/openai/types as openai_types
import tidal_ai_playlist/internal/playlist_parser
import tidal_ai_playlist/internal/types

const prompt = "> "

type State {
  AskAI(messages: List(openai_types.ResponsesInput), retries: Int)
  ParseAIResponse(
    reply: String,
    messages: List(openai_types.ResponsesInput),
    retries: Int,
  )
  ConfirmPlaylist(
    songs: List(types.Track),
    messages: List(openai_types.ResponsesInput),
  )
  AskTitle(songs: List(types.Track))
  AskDescription(songs: List(types.Track), title: String)
  AskForChanges(messages: List(openai_types.ResponsesInput))
  Done(types.Playlist)
}

pub fn interactive_playlist_flow(
  config: config.Config,
  deps: types.Dependencies,
) -> Result(types.Playlist, errors.TidalAIPlaylistError) {
  let assert Ok(first_prompt) =
    ask_user(deps, "What music would you like to listen to today?")
  let initial_messages = [openai_types.ResponsesInput("user", first_prompt)]
  run_state(config, deps, AskAI(initial_messages, 0))
}

fn run_state(
  config: config.Config,
  deps: types.Dependencies,
  state: State,
) -> Result(types.Playlist, errors.TidalAIPlaylistError) {
  case state {
    AskAI(messages, retries) -> {
      case retries >= 3 {
        True -> Error(errors.MaxNumberOfOpenAIRetries)
        False -> {
          case openai_api.ask(messages, config.openai_config) {
            Ok(reply) ->
              run_state(config, deps, ParseAIResponse(reply, messages, retries))
            Error(reason) -> Error(reason)
          }
        }
      }
    }

    ParseAIResponse(reply, messages, retries) -> {
      let songs =
        playlist_parser.parse(reply)
        |> list.filter(fn(r) {
          case r {
            types.Track(_, _) -> True
          }
        })

      case list.is_empty(songs) {
        True -> {
          deps.output_fn(
            "No songs could be parsed. Asking AI to correct the format...",
          )
          let new_messages =
            list.append(messages, [
              openai_types.ResponsesInput("assistant", reply),
              openai_types.ResponsesInput(
                "user",
                "Please resend the playlist in TSV format: Artist<TAB>Title per line",
              ),
            ])
          run_state(config, deps, AskAI(new_messages, retries + 1))
        }
        False -> {
          run_state(config, deps, ConfirmPlaylist(songs, messages))
        }
      }
    }

    ConfirmPlaylist(songs, messages) -> {
      deps.output_fn("\nProposed Playlist:\n")
      list.map(songs, fn(song) {
        deps.output_fn(song.artist <> "\t" <> song.title)
      })
      let assert Ok(ans) = ask_user(deps, "Generate this playlist? (y/n)")

      case string.trim(ans) {
        "y" -> {
          run_state(config, deps, AskTitle(songs))
        }
        _ -> {
          run_state(config, deps, AskForChanges(messages))
        }
      }
    }

    AskTitle(songs) -> {
      let assert Ok(title) =
        ask_user(deps, "What would you like to name the playlist?")
      run_state(config, deps, AskDescription(songs, title))
    }

    AskDescription(songs, title) -> {
      let assert Ok(description) =
        ask_user(deps, "What would you like to set for the description?")
      run_state(
        config,
        deps,
        Done(types.Playlist(
          songs: songs,
          title: title,
          description: description,
        )),
      )
    }

    AskForChanges(messages) -> {
      let assert Ok(new_prompt) = ask_user(deps, "What would you like changed?")
      let new_messages =
        list.append(messages, [openai_types.ResponsesInput("user", new_prompt)])
      run_state(config, deps, AskAI(new_messages, 0))
    }

    Done(playlist) -> {
      Ok(playlist)
    }
  }
}

fn ask_user(dependencies: types.Dependencies, question) -> Result(String, Nil) {
  dependencies.output_fn(question)
  dependencies.input_fn(prompt)
}
