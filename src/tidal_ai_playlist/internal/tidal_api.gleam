import gleam/http
import gleam/http/request
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam/uri
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http as tidal_http
import tidal_ai_playlist/internal/tidal_json

const base_auth_host = "auth.tidal.com"

const base_host = "api.tidal.com"

const device_authorization_path = "/v1/oauth2/device_authorization"

const scope = "r_usr w_usr w_sub"

const device_code_grant_type = "urn:ietf:params:oauth:grant-type:device_code"

const token_path = "/v1/oauth2/token"

const client_version = "2025.7.16"

const search_path = "/v1/search"

const user_agent = "Mozilla/5.0 (Linux; Android 12; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/91.0.4472.114 Safari/537.36"

pub fn authorize_device(client_id: String) -> request.Request(String) {
  let body = "client_id=" <> client_id <> "&scope=r_usr w_usr w_sub"
  base_client()
  |> request.set_path(device_authorization_path)
  |> request.set_body(body)
  |> request.prepend_header("Content-Type", "application/x-www-form-urlencoded")
  |> request.set_method(http.Post)
}

pub fn do_refresh_token(
  client_id: String,
  client_secret: String,
  refresh_token: String,
) -> Result(tidal_json.RefreshTokenResponse, errors.TidalAPIError) {
  let sender = tidal_http.default_client
  case sender(exchange_refresh_token(client_id, client_secret, refresh_token)) {
    Ok(response) -> tidal_json.decode_refresh_token_response(response.body)
    Error(err) -> Error(err)
  }
}

pub fn do_search_track(
  artist: String,
  song: String,
  access_token: String,
  session_id: String,
) -> Result(tidal_json.SearchTrackResponse, errors.TidalAPIError) {
  let sender = tidal_http.default_client
  case sender(search_track(artist, song, access_token, session_id)) {
    Ok(response) -> tidal_json.decode_search_track_response(response.body)
    Error(err) -> Error(err)
  }
}

fn build_playlist_path(user_id: Int) -> String {
  "/v1/users/" <> int.to_string(user_id) <> "/playlists"
}

fn build_playlist_items_path(playlist_id: String) -> String {
  "/v1/playlists/" <> playlist_id <> "/items"
}

pub fn do_create_playlist(
  user_id: Int,
  title: String,
  description: String,
  access_token: String,
  session_id: String,
) -> Result(tidal_json.CreatePlaylistResponse, errors.TidalAPIError) {
  let sender = tidal_http.default_client
  case
    sender(create_playlist(
      user_id,
      title,
      description,
      access_token,
      session_id,
    ))
  {
    Ok(response) -> {
      case tidal_json.decode_create_playlist_response(response.body) {
        Ok(decoded_response) ->
          Ok(tidal_json.CreatePlaylistResponse(
            id: decoded_response.id,
            etag: response.etag,
          ))
        Error(err) -> Error(err)
      }
    }
    Error(err) -> Error(err)
  }
}

pub fn create_playlist(
  user_id: Int,
  title: String,
  description: String,
  access_token: String,
  session_id: String,
) -> request.Request(String) {
  let body =
    "title="
    <> uri.percent_encode(title)
    <> "&description="
    <> uri.percent_encode(description)
    <> "&countryCode="
    <> uri.percent_encode("GB")
    <> "&sessionId="
    <> uri.percent_encode(session_id)

  io.println("Path: " <> build_playlist_path(user_id))

  base_client()
  |> request.set_path(build_playlist_path(user_id))
  |> request.prepend_header("authorization", "Bearer " <> access_token)
  |> request.prepend_header("content-type", "application/x-www-form-urlencoded")
  |> request.set_host(base_host)
  |> request.set_body(body)
  |> request.set_method(http.Post)
}

pub fn search_track(
  artist: String,
  song: String,
  access_token: String,
  session_id: String,
) -> request.Request(String) {
  let query = [
    #("query", artist <> " " <> song),
    #("limit", "50"),
    #("offset", "0"),
    #("types", "TRACKS"),
    #("sessionId", session_id),
    #("countryCode", "GB"),
  ]
  base_client()
  |> request.set_path(search_path)
  |> request.set_method(http.Get)
  |> request.prepend_header("authorization", "Bearer " <> access_token)
  |> request.prepend_header("Content-Type", "application/x-www-form-urlencoded")
  |> request.set_host(base_host)
  |> request.set_query(query)
}

pub fn exchange_refresh_token(
  client_id: String,
  client_secret: String,
  refresh_token: String,
) -> request.Request(String) {
  let body =
    "grant_type=refresh_token&refresh_token="
    <> refresh_token
    <> "&client_id="
    <> client_id
    <> "&client_secret="
    <> client_secret
  base_client()
  |> request.set_path(token_path)
  |> request.prepend_header("Content-Type", "application/x-www-form-urlencoded")
  |> request.set_method(http.Post)
  |> request.set_body(body)
}

pub fn exchange_device_code_for_token(
  client_id: String,
  client_secret: String,
  device_code: String,
) -> request.Request(String) {
  let body =
    "client_id="
    <> client_id
    <> "&scope="
    <> scope
    <> "&client_secret="
    <> client_secret
    <> "&device_code="
    <> device_code
    <> "&grant_type="
    <> device_code_grant_type
  base_client()
  |> request.set_path(token_path)
  |> request.prepend_header("Content-Type", "application/x-www-form-urlencoded")
  |> request.set_method(http.Post)
  |> request.set_body(body)
}

pub fn do_add_tracks_to_playlist(
  playlist_id: String,
  song_ids: List(Int),
  access_token: String,
  session_id: String,
  etag: String,
) -> Result(tidal_json.AddTracksToPlaylistResponse, errors.TidalAPIError) {
  let sender = tidal_http.default_client
  case
    sender(add_tracks_to_playlist(
      playlist_id,
      song_ids,
      access_token,
      session_id,
      etag,
    ))
  {
    Ok(response) ->
      tidal_json.decode_add_tracks_to_playlist_response(response.body)
    Error(err) -> Error(err)
  }
}

pub fn add_tracks_to_playlist(
  playlist_id: String,
  song_ids: List(Int),
  access_token: String,
  session_id: String,
  etag: String,
) {
  let song_ids_strings = list.map(song_ids, fn(i) { int.to_string(i) })
  let body =
    "trackIds="
    <> string.join(song_ids_strings, ",")
    <> "&onDupes=SKIP"
    <> "&countryCode=GB"
    <> "&sessionId="
    <> session_id
  io.println(build_playlist_items_path(playlist_id))
  io.println(etag)
  base_client()
  |> request.set_path(build_playlist_items_path(playlist_id))
  |> request.set_host(base_host)
  |> request.prepend_header("authorization", "Bearer " <> access_token)
  |> request.prepend_header("Content-Type", "application/x-www-form-urlencoded")
  |> request.prepend_header("If-None-Match", etag)
  |> request.set_method(http.Post)
  |> request.set_body(body)
}

fn base_client() -> request.Request(String) {
  request.new()
  |> request.set_scheme(http.Https)
  |> request.prepend_header("User-Agent", user_agent)
  |> request.prepend_header("x-tidal-client-version", client_version)
  |> request.set_host(base_auth_host)
}
