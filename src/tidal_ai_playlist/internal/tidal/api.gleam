import gleam/erlang/process
import gleam/http/request
import gleam/io
import gleam/option
import gleam/result

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/option as tidal_ai_playlist_option
import tidal_ai_playlist/internal/tidal/decoders
import tidal_ai_playlist/internal/tidal/http as tidal_http
import tidal_ai_playlist/internal/tidal/types

pub fn login(
  config: types.Config,
) -> Result(types.OauthToken, errors.TidalAIPlaylistError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  let output_fn = option.unwrap(config.output_fn, io.println)
  case authorize_device(config) {
    Ok(device_authorization_response) -> {
      output_fn(
        "authorization code: " <> device_authorization_response.user_code,
      )
      output_fn(
        "Please login at: "
        <> device_authorization_response.verification_uri
        <> " and paste the code above.",
      )
      poll_device_authorization(
        device_authorization_response.expires_in,
        device_authorization_response.interval,
        config,
        device_authorization_response,
        http_client,
      )
    }

    Error(err) -> Error(err)
  }
}

pub fn refresh_token(
  config: types.Config,
) -> Result(types.RefreshTokenResponse, errors.TidalAIPlaylistError) {
  use refresh_token <- result.try(tidal_ai_playlist_option.from_option(
    config.refresh_token,
    errors.TidalRefreshTokenMissing,
  ))
  let http_client = option.unwrap(config.http_client, http.default_client)
  case http_client(tidal_http.exchange_refresh_token(config, refresh_token)) {
    Ok(response) -> decoders.decode_refresh_token_response(response.body)
    Error(err) -> Error(err)
  }
}

pub fn authorize_device(
  config: types.Config,
) -> Result(types.DeviceAuthorizationResponse, errors.TidalAIPlaylistError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  let req = tidal_http.authorize_device(config.client_id)

  case http_client(req) {
    Ok(response) -> decoders.decode_device_authorization_response(response.body)
    Error(err) -> Error(err)
  }
}

pub fn exchange_device_code_for_token(
  config: types.Config,
  device_code: String,
) -> Result(types.OauthToken, errors.TidalAIPlaylistError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  let req = tidal_http.exchange_device_code_for_token(config, device_code)
  case http_client(req) {
    Ok(resp) ->
      case resp.status {
        200 -> decoders.decode_oauth_token_response(resp.body)
        400 -> Error(errors.TidalDeviceAuthorizationNotReady)
        _ -> Error(errors.OtherError("Unexpected status code from tidal api"))
      }

    Error(err) -> Error(err)
  }
}

pub fn create_playlist(
  config: types.Config,
  title: String,
  description: String,
) -> Result(types.CreatePlaylistResponse, errors.TidalAIPlaylistError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  use access_token <- result.try(tidal_ai_playlist_option.from_option(
    config.access_token,
    errors.TidalAccessTokenMissing,
  ))
  use user_id <- result.try(tidal_ai_playlist_option.from_option(
    config.user_id,
    errors.TidalUserIdMissing,
  ))

  case
    http_client(tidal_http.create_playlist(
      user_id,
      title,
      description,
      access_token,
      config.session_id,
    ))
  {
    Ok(response) -> {
      case decoders.decode_create_playlist_response(response.body) {
        Ok(decoded_response) ->
          Ok(types.CreatePlaylistResponse(
            id: decoded_response.id,
            etag: response.etag,
          ))
        Error(err) -> Error(err)
      }
    }
    Error(err) -> Error(err)
  }
}

pub fn search_track(
  config: types.Config,
  artist: String,
  song: String,
) -> Result(types.SearchTrackResponse, errors.TidalAIPlaylistError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  use access_token <- result.try(tidal_ai_playlist_option.from_option(
    config.access_token,
    errors.TidalAccessTokenMissing,
  ))

  case
    http_client(tidal_http.search_track(
      artist,
      song,
      access_token,
      config.session_id,
    ))
  {
    Ok(response) -> decoders.decode_search_track_response(response.body)
    Error(err) -> Error(err)
  }
}

pub fn add_tracks_to_playlist(
  config: types.Config,
  playlist_id: String,
  song_ids: List(Int),
  etag: String,
) -> Result(types.AddTracksToPlaylistResponse, errors.TidalAIPlaylistError) {
  use access_token <- result.try(access_token(config))
  get(
    config,
    tidal_http.add_tracks_to_playlist(
      playlist_id,
      song_ids,
      access_token,
      etag,
      config.session_id,
    ),
    decoders.decode_add_tracks_to_playlist,
  )
}

fn poll_device_authorization(
  remaining: Int,
  interval: Int,
  config: types.Config,
  device: types.DeviceAuthorizationResponse,
  client: http.Client,
) -> Result(types.OauthToken, errors.TidalAIPlaylistError) {
  case remaining <= 0 {
    True -> Error(errors.TidalDeviceAuthorizationExpiredError)
    False -> {
      case exchange_device_code_for_token(config, device.device_code) {
        Ok(response) -> Ok(response)
        Error(errors.TidalDeviceAuthorizationNotReady) -> {
          process.sleep(interval * 1000)
          poll_device_authorization(
            remaining - interval,
            interval,
            config,
            device,
            client,
          )
        }
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn search_tracks(
  config: types.Config,
  query: String,
  limit: Int,
) -> Result(types.Paged(types.Track), errors.TidalAIPlaylistError) {
  use access_token <- result.try(access_token(config))
  get(
    config,
    tidal_http.search_tracks(query, limit, access_token, config.session_id),
    decoders.decode_search_tracks_response,
  )
}

pub fn list_playlists(
  config: types.Config,
  limit: Int,
  offset: Int,
) -> Result(types.Paged(types.PlaylistSummary), errors.TidalAIPlaylistError) {
  use access_token <- result.try(access_token(config))
  use user_id <- result.try(user_id(config))
  get(
    config,
    tidal_http.user_playlists(user_id, limit, offset, access_token),
    decoders.decode_playlists_response,
  )
}

pub fn playlist_tracks(
  config: types.Config,
  playlist_id: String,
  limit: Int,
  offset: Int,
) -> Result(types.Paged(types.Track), errors.TidalAIPlaylistError) {
  use access_token <- result.try(access_token(config))
  get(
    config,
    tidal_http.playlist_items(playlist_id, limit, offset, access_token),
    decoders.decode_playlist_items_response,
  )
}

/// The playlist's current ETag, which Tidal requires when changing it.
pub fn playlist_etag(
  config: types.Config,
  playlist_id: String,
) -> Result(String, errors.TidalAIPlaylistError) {
  use access_token <- result.try(access_token(config))
  use response <- result.map(send(
    config,
    tidal_http.playlist(playlist_id, access_token),
  ))
  response.etag
}

pub fn favorite_tracks(
  config: types.Config,
  limit: Int,
  offset: Int,
) -> Result(
  types.Paged(types.Favorite(types.Track)),
  errors.TidalAIPlaylistError,
) {
  favorites(
    config,
    "tracks",
    limit,
    offset,
    decoders.decode_favorite_tracks_response,
  )
}

pub fn favorite_albums(
  config: types.Config,
  limit: Int,
  offset: Int,
) -> Result(
  types.Paged(types.Favorite(types.Album)),
  errors.TidalAIPlaylistError,
) {
  favorites(
    config,
    "albums",
    limit,
    offset,
    decoders.decode_favorite_albums_response,
  )
}

pub fn favorite_artists(
  config: types.Config,
  limit: Int,
  offset: Int,
) -> Result(
  types.Paged(types.Favorite(types.Artist)),
  errors.TidalAIPlaylistError,
) {
  favorites(
    config,
    "artists",
    limit,
    offset,
    decoders.decode_favorite_artists_response,
  )
}

fn favorites(
  config: types.Config,
  kind: String,
  limit: Int,
  offset: Int,
  decode: fn(String) -> Result(a, errors.TidalAIPlaylistError),
) -> Result(a, errors.TidalAIPlaylistError) {
  use access_token <- result.try(access_token(config))
  use user_id <- result.try(user_id(config))
  get(
    config,
    tidal_http.favorites(user_id, kind, limit, offset, access_token),
    decode,
  )
}

fn get(
  config: types.Config,
  req: request.Request(String),
  decode: fn(String) -> Result(a, errors.TidalAIPlaylistError),
) -> Result(a, errors.TidalAIPlaylistError) {
  use response <- result.try(send(config, req))
  decode(response.body)
}

fn send(
  config: types.Config,
  req: request.Request(String),
) -> Result(http.HttpResponse, errors.TidalAIPlaylistError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  use response <- result.try(http_client(req))
  case response.status {
    200 -> Ok(response)
    status -> Error(errors.TidalApiError(status, response.body))
  }
}

fn access_token(
  config: types.Config,
) -> Result(String, errors.TidalAIPlaylistError) {
  tidal_ai_playlist_option.from_option(
    config.access_token,
    errors.TidalAccessTokenMissing,
  )
}

fn user_id(config: types.Config) -> Result(Int, errors.TidalAIPlaylistError) {
  tidal_ai_playlist_option.from_option(
    config.user_id,
    errors.TidalUserIdMissing,
  )
}
