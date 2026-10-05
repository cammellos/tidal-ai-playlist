import gleam/json
import gleam/list
import gleam/option
import gleam/result

import simplifile

import tidal_ai_playlist/internal/cli
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/openai/api as openai_api
import tidal_ai_playlist/internal/openai/config as openai_config
import tidal_ai_playlist/internal/openai/types as openai_types
import tidal_ai_playlist/internal/playlist_parser
import tidal_ai_playlist/internal/session
import tidal_ai_playlist/internal/tidal/api as tidal_api
import tidal_ai_playlist/internal/tidal/config as tidal_config
import tidal_ai_playlist/internal/tidal/encoders
import tidal_ai_playlist/internal/tidal/types as tidal_types
import tidal_ai_playlist/internal/types

const max_openai_attempts = 3

/// Runs a non-interactive command and returns its JSON output.
pub fn execute(
  command: cli.Command,
  dependencies: types.Dependencies,
) -> Result(String, errors.TidalAIPlaylistError) {
  case command {
    cli.Login(output) -> login(dependencies, output)
    _ -> {
      use config <- result.try(session.load_tidal_config(
        dependencies,
        session.RequireSavedLogin,
      ))
      use output <- result.map(run(command, config, dependencies))
      json.to_string(output)
    }
  }
}

fn run(
  command: cli.Command,
  config: tidal_types.Config,
  dependencies: types.Dependencies,
) -> Result(json.Json, errors.TidalAIPlaylistError) {
  case command {
    cli.Search(query, limit) ->
      tidal_api.search_tracks(config, query, limit)
      |> result.map(encoders.paged(_, encoders.track))

    cli.ListPlaylists(cli.Page(limit, offset)) ->
      tidal_api.list_playlists(config, limit, offset)
      |> result.map(encoders.paged(_, encoders.playlist))

    cli.PlaylistTracks(playlist_id, cli.Page(limit, offset)) ->
      tidal_api.playlist_tracks(config, playlist_id, limit, offset)
      |> result.map(encoders.paged(_, encoders.track))

    cli.Favorites(cli.FavoriteTracks, cli.Page(limit, offset)) ->
      tidal_api.favorite_tracks(config, limit, offset)
      |> result.map(encoders.paged(_, encoders.favorite(_, encoders.track)))

    cli.Favorites(cli.FavoriteAlbums, cli.Page(limit, offset)) ->
      tidal_api.favorite_albums(config, limit, offset)
      |> result.map(encoders.paged(_, encoders.favorite(_, encoders.album)))

    cli.Favorites(cli.FavoriteArtists, cli.Page(limit, offset)) ->
      tidal_api.favorite_artists(config, limit, offset)
      |> result.map(encoders.paged(_, encoders.favorite(_, encoders.artist)))

    cli.CreatePlaylist(title, description) -> {
      use playlist <- result.map(tidal_api.create_playlist(
        config,
        title,
        description,
      ))
      created_playlist(playlist.id, title)
    }

    cli.AddTracks(playlist_id, track_ids) -> {
      use etag <- result.try(tidal_api.playlist_etag(config, playlist_id))
      use response <- result.map(tidal_api.add_tracks_to_playlist(
        config,
        playlist_id,
        track_ids,
        etag,
      ))
      json.object([
        #("uuid", json.string(playlist_id)),
        #("added", json.int(list.length(response.added_item_ids))),
      ])
    }

    cli.Generate(prompt, title, description) ->
      generate(config, dependencies, prompt, title, description)

    cli.Interactive | cli.Help | cli.Login(_) ->
      Error(errors.OtherError("not a non-interactive command"))
  }
}

fn login(
  dependencies: types.Dependencies,
  output: String,
) -> Result(String, errors.TidalAIPlaylistError) {
  use config <- result.try(tidal_config.from_env(dependencies.get_env_fn))
  let config =
    config
    |> tidal_config.add_http_client(dependencies.http_client)
    |> tidal_config.add_output_fn(dependencies.output_fn)
  use token <- result.try(tidal_api.login(config))

  // Restrict the file before the refresh token goes into it.
  use _ <- result.try(
    simplifile.write(to: output, contents: "")
    |> result.try(fn(_) { simplifile.set_permissions_octal(output, 0o600) })
    |> result.try(fn(_) {
      simplifile.write(
        to: output,
        contents: json.to_string(
          json.object([
            #("refresh_token", json.string(token.refresh_token)),
            #("user_id", json.int(token.user_id)),
          ]),
        ),
      )
    })
    |> result.replace_error(errors.TidalWritingConfigError),
  )

  Ok(
    json.to_string(
      json.object([
        #("saved_to", json.string(output)),
        #("user_id", json.int(token.user_id)),
      ]),
    ),
  )
}

/// Asks OpenAI for a playlist, creates it on Tidal with the best match for
/// each suggestion, and reports what couldn't be found.
fn generate(
  config: tidal_types.Config,
  dependencies: types.Dependencies,
  prompt: String,
  title: option.Option(String),
  description: String,
) -> Result(json.Json, errors.TidalAIPlaylistError) {
  use openai <- result.try(openai_config.from_env(
    openai_config.playlist_instructions,
    dependencies.get_env_fn,
  ))
  let openai = openai_config.add_http_client(openai, dependencies.http_client)
  use songs <- result.try(ask_for_songs(
    openai,
    [openai_types.ResponsesInput("user", prompt)],
    1,
  ))

  let #(found, not_found) =
    list.map(songs, fn(song) {
      case
        tidal_api.search_tracks(config, song.artist <> " " <> song.title, 1)
      {
        Ok(tidal_types.Paged(items: [track, ..], ..)) -> Ok(track)
        _ -> Error(song)
      }
    })
    |> result.partition

  let title = option.unwrap(title, prompt)
  use playlist <- result.try(tidal_api.create_playlist(
    config,
    title,
    description,
  ))
  use _ <- result.try(case found {
    [] -> Ok(Nil)
    _ ->
      tidal_api.add_tracks_to_playlist(
        config,
        playlist.id,
        list.reverse(found) |> list.map(fn(track) { track.id }),
        playlist.etag,
      )
      |> result.replace(Nil)
  })

  Ok(
    json.object([
      #("uuid", json.string(playlist.id)),
      #("title", json.string(title)),
      #("url", json.string(encoders.playlist_url(playlist.id))),
      #("added", json.array(list.reverse(found), encoders.track)),
      #(
        "not_found",
        json.array(list.reverse(not_found), fn(song: types.Track) {
          json.object([
            #("artist", json.string(song.artist)),
            #("title", json.string(song.title)),
          ])
        }),
      ),
    ]),
  )
}

fn ask_for_songs(
  openai: openai_config.Config,
  messages: List(openai_types.ResponsesInput),
  attempt: Int,
) -> Result(List(types.Track), errors.TidalAIPlaylistError) {
  use reply <- result.try(openai_api.ask(messages, openai))
  case playlist_parser.parse(reply), attempt >= max_openai_attempts {
    [], True -> Error(errors.MaxNumberOfOpenAIRetries)
    [], False ->
      ask_for_songs(
        openai,
        list.append(messages, [
          openai_types.ResponsesInput("assistant", reply),
          openai_types.ResponsesInput(
            "user",
            "Please resend the playlist in TSV format: Artist<TAB>Title per line",
          ),
        ]),
        attempt + 1,
      )
    songs, _ -> Ok(songs)
  }
}

fn created_playlist(uuid: String, title: String) -> json.Json {
  json.object([
    #("uuid", json.string(uuid)),
    #("title", json.string(title)),
    #("url", json.string(encoders.playlist_url(uuid))),
  ])
}
