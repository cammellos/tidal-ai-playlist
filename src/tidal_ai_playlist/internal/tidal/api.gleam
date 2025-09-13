import gleam/erlang/process
import gleam/io
import gleam/option
import gleam/result

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/option as tidal_ai_playlist_option
import tidal_ai_playlist/internal/tidal/config
import tidal_ai_playlist/internal/tidal/decoders
import tidal_ai_playlist/internal/tidal/http as tidal_http
import tidal_ai_playlist/internal/tidal/types

pub fn login(
  config: types.Config,
) -> Result(types.OauthToken, errors.TidalAPIError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  case authorize_device(config) {
    Ok(device_authorization_response) -> {
      io.println(
        "authorization code: " <> device_authorization_response.user_code,
      )
      io.println(
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
) -> Result(types.RefreshTokenResponse, errors.TidalAPIError) {
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
) -> Result(types.DeviceAuthorizationResponse, errors.TidalAPIError) {
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
) -> Result(types.OauthToken, errors.TidalAPIError) {
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
) -> Result(types.CreatePlaylistResponse, errors.TidalAPIError) {
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
) -> Result(types.SearchTrackResponse, errors.TidalAPIError) {
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
) -> Result(String, errors.TidalAPIError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  use access_token <- result.try(tidal_ai_playlist_option.from_option(
    config.access_token,
    errors.TidalAccessTokenMissing,
  ))

  case
    http_client(tidal_http.add_tracks_to_playlist(
      playlist_id,
      song_ids,
      access_token,
      etag,
      config.session_id,
    ))
  {
    Ok(response) -> Ok(response.body)
    Error(err) -> Error(err)
  }
}

fn poll_device_authorization(
  remaining: Int,
  interval: Int,
  config: types.Config,
  device: types.DeviceAuthorizationResponse,
  client: http.Client,
) -> Result(types.OauthToken, errors.TidalAPIError) {
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
