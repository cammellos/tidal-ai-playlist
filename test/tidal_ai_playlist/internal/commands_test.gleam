import gleam/http/request
import gleam/string

import tidal_ai_playlist/fixtures
import tidal_ai_playlist/internal/cli
import tidal_ai_playlist/internal/commands
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/types

pub fn list_playlists_test() {
  let assert Ok(output) =
    commands.execute(cli.ListPlaylists(cli.Page(2, 0)), dependencies(logged_in))
  assert string.contains(output, "\"uuid\":\"pl-1\"")
  assert string.contains(output, "\"total\":22")
}

pub fn requires_saved_login_test() {
  assert commands.execute(
      cli.ListPlaylists(cli.Page(2, 0)),
      dependencies(fn(key) {
        case key {
          "TIDAL_CLIENT_ID" -> Ok("id")
          "TIDAL_CLIENT_SECRET" -> Ok("secret")
          _ -> Error(Nil)
        }
      }),
    )
    == Error(errors.TidalRefreshTokenMissing)
}

pub fn add_uses_playlist_etag_test() {
  let assert Ok(output) =
    commands.execute(cli.AddTracks("pl-1", [1, 2]), dependencies(logged_in))
  assert output == "{\"uuid\":\"pl-1\",\"added\":2}"
}

pub fn api_error_status_test() {
  assert commands.execute(
      cli.PlaylistTracks("missing", cli.Page(10, 0)),
      dependencies(logged_in),
    )
    == Error(errors.TidalApiError(404, "not found"))
}

fn logged_in(key: String) -> Result(String, Nil) {
  case key {
    "TIDAL_CLIENT_ID" -> Ok("id")
    "TIDAL_CLIENT_SECRET" -> Ok("secret")
    "TIDAL_REFRESH_TOKEN" -> Ok("refresh-token")
    "TIDAL_USER_ID" -> Ok("1")
    _ -> Error(Nil)
  }
}

fn dependencies(
  get_env_fn: fn(String) -> Result(String, Nil),
) -> types.Dependencies {
  types.Dependencies(
    get_env_fn: get_env_fn,
    output_fn: fn(_) { Nil },
    http_client: client,
    input_fn: fn(_) { Error(Nil) },
  )
}

fn client(
  req: request.Request(String),
) -> Result(http.HttpResponse, errors.TidalAIPlaylistError) {
  case req.path, req.headers {
    "/v1/oauth2/token", _ -> ok(fixtures.refresh_token_response, "")
    "/v1/users/1/playlists", _ -> ok(fixtures.playlists_response, "")
    "/v1/playlists/pl-1", _ -> ok(fixtures.create_playlist_response, "\"42\"")
    // Adding only succeeds with the playlist's current ETag.
    "/v1/playlists/pl-1/items", headers ->
      case has_header(headers, "if-none-match", "\"42\"") {
        True -> ok(fixtures.add_tracks_to_playlist_response, "")
        False -> Ok(http.HttpResponse(status: 412, body: "", etag: ""))
      }
    _, _ -> Ok(http.HttpResponse(status: 404, body: "not found", etag: ""))
  }
}

fn has_header(
  headers: List(#(String, String)),
  name: String,
  value: String,
) -> Bool {
  case headers {
    [] -> False
    [#(n, v), ..] if n == name && v == value -> True
    [_, ..rest] -> has_header(rest, name, value)
  }
}

fn ok(
  body: String,
  etag: String,
) -> Result(http.HttpResponse, errors.TidalAIPlaylistError) {
  Ok(http.HttpResponse(status: 200, body: body, etag: etag))
}

pub fn add_with_stale_etag_reports_status_test() {
  let stale_client = fn(req: request.Request(String)) {
    case req.path {
      "/v1/playlists/pl-1" -> ok(fixtures.create_playlist_response, "\"41\"")
      _ -> client(req)
    }
  }
  assert commands.execute(
      cli.AddTracks("pl-1", [1]),
      types.Dependencies(..dependencies(logged_in), http_client: stale_client),
    )
    == Error(errors.TidalApiError(412, ""))
}
