import gleam/erlang/process
import gleam/io
import gleam/option

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/tidal/config
import tidal_ai_playlist/internal/tidal/decoders
import tidal_ai_playlist/internal/tidal/http as tidal_http
import tidal_ai_playlist/internal/tidal/types

pub fn login(config: config.Config) -> Result(String, errors.TidalAPIError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  case authorize_device(config) {
    Ok(device_authorization_response) -> {
      io.println(
        "authorization code: " <> device_authorization_response.user_code,
      )
      io.println(
        "please login at: "
        <> device_authorization_response.verification_uri
        <> " and paste the code above.",
      )
      case
        poll_device_authorization(
          device_authorization_response.expires_in,
          device_authorization_response.interval,
          config,
          device_authorization_response,
          http_client,
        )
      {
        Ok(oauth_token) -> {
          io.println("oauth token fetched successfully: ")
          io.println("access_token: " <> oauth_token.access_token)
          io.println("refresh_token: " <> oauth_token.refresh_token)

          Ok("success")
        }
        Error(err) -> Error(err)
      }
    }

    Error(err) -> Error(err)
  }
}

pub fn refresh_token(
  config: config.Config,
  refresh_token: String,
) -> Result(types.RefreshTokenResponse, errors.TidalAPIError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  case http_client(tidal_http.exchange_refresh_token(config, refresh_token)) {
    Ok(response) -> decoders.decode_refresh_token_response(response.body)
    Error(err) -> Error(err)
  }
}

pub fn authorize_device(
  config: config.Config,
) -> Result(types.DeviceAuthorizationResponse, errors.TidalAPIError) {
  let http_client = http.default_client
  let req = tidal_http.authorize_device(config.client_id)

  case http_client(req) {
    Ok(response) -> decoders.decode_device_authorization_response(response.body)
    Error(err) -> Error(err)
  }
}

pub fn exchange_device_code_for_token(
  config: config.Config,
  device_code: String,
) -> Result(types.OauthToken, errors.TidalAPIError) {
  let http_client = http.default_client
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

fn poll_device_authorization(
  remaining: Int,
  interval: Int,
  config: config.Config,
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
