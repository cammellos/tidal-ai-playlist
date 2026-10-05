import gleam/io
import gleam/list
import gleam/result

import argv
import envoy
import input

import tidal_ai_playlist/internal/cli
import tidal_ai_playlist/internal/commands
import tidal_ai_playlist/internal/config
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/interactive
import tidal_ai_playlist/internal/openai/config as openai_config
import tidal_ai_playlist/internal/session
import tidal_ai_playlist/internal/tidal/api as tidal_api
import tidal_ai_playlist/internal/types

pub fn main() -> Nil {
  let dependencies =
    types.Dependencies(
      get_env_fn: envoy.get,
      output_fn: io.println,
      http_client: http.default_client,
      input_fn: input.input,
    )
  case cli.parse(argv.load().arguments) {
    Ok(cli.Interactive) -> {
      let assert Ok(_) = run(dependencies)
      Nil
    }
    Ok(cli.Help) -> io.println(cli.usage)
    Ok(command) ->
      case commands.execute(command, dependencies) {
        Ok(output) -> io.println(output)
        Error(err) -> {
          io.println_error(errors.error_to_string(err))
          halt(1)
        }
      }
    Error(message) -> {
      io.println_error(message <> "\n\n" <> cli.usage)
      halt(2)
    }
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

pub fn run(
  dependencies: types.Dependencies,
) -> Result(types.Playlist, errors.TidalAIPlaylistError) {
  use config <- result.try(default_config(dependencies))

  use playlist <- result.try(interactive.interactive_playlist_flow(
    config,
    dependencies,
  ))
  create_tidal_playlist_from_openai(config, playlist)
}

fn default_config(
  dependencies: types.Dependencies,
) -> Result(config.Config, errors.TidalAIPlaylistError) {
  use openai_built_config <- result.try(openai_config.from_env(
    openai_config.playlist_instructions,
    dependencies.get_env_fn,
  ))
  use tidal_config <- result.try(session.load_tidal_config(
    dependencies,
    session.AllowDeviceLogin,
  ))
  Ok(config.Config(
    openai_config: openai_built_config
      |> openai_config.add_http_client(dependencies.http_client),
    tidal_config: tidal_config,
  ))
}

pub fn create_tidal_playlist_from_openai(
  config: config.Config,
  playlist: types.Playlist,
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

  use _ <- result.try(tidal_api.add_tracks_to_playlist(
    tidal_config,
    new_playlist.id,
    track_ids,
    new_playlist.etag,
  ))

  Ok(playlist)
}
