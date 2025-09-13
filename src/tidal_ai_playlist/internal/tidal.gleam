import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/int
import gleam/io
import gleam/json
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http as tidal_http
import tidal_ai_playlist/internal/json as tidal_json
import tidal_ai_playlist/internal/tidal_api

type DeviceAuthorizationResponse {
  DeviceAuthorizationResponse(
    device_code: String,
    user_code: String,
    verification_uri: String,
    verification_uri_complete: String,
    expires_in: Int,
    interval: Int,
  )
}

type OauthToken {
  OauthToken(
    access_token: String,
    refresh_token: String,
    expires_in: Int,
    user_id: Int,
  )
}

fn oauth_token_decoder() -> decode.Decoder(OauthToken) {
  {
    use access_token <- decode.field("access_token", decode.string)
    use refresh_token <- decode.field("refresh_token", decode.string)
    use expires_in <- decode.field("expires_in", decode.int)
    use user_id <- decode.field("user_id", decode.int)
    decode.success(OauthToken(access_token, refresh_token, expires_in, user_id))
  }
}

pub type Config {
  Config(client_id: String, client_secret: String)
}

pub fn login(config: Config) -> Result(String, errors.TidalError) {
  login_with_sender(config, tidal_http.default_client)
}

pub fn login_with_sender(
  config: Config,
  sender: tidal_http.Client,
) -> Result(String, errors.TidalError) {
  case get_login_url(config, sender) {
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
        do_poll_device_authorization(
          device_authorization_response.expires_in,
          device_authorization_response.interval,
          config,
          device_authorization_response,
          sender,
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

fn get_login_url(
  config: Config,
  sender: tidal_http.Client,
) -> Result(DeviceAuthorizationResponse, errors.TidalError) {
  let req = tidal_api.authorize_device(config.client_id)

  case sender(req) {
    Ok(response) -> decode_device_authorization_response(response.body)
    Error(err) -> Error(err)
  }
}

fn device_authorization_decoder() -> decode.Decoder(DeviceAuthorizationResponse) {
  {
    use device_code <- decode.field("deviceCode", decode.string)
    use user_code <- decode.field("userCode", decode.string)
    use verification_uri <- decode.field("verificationUri", decode.string)
    use verification_uri_complete <- decode.field(
      "verificationUriComplete",
      decode.string,
    )
    use expires_in <- decode.field("expiresIn", decode.int)
    use interval <- decode.field("interval", decode.int)

    decode.success(DeviceAuthorizationResponse(
      device_code: device_code,
      user_code: user_code,
      verification_uri: verification_uri,
      verification_uri_complete: verification_uri_complete,
      expires_in: expires_in,
      interval: interval,
    ))
  }
}

fn decode_device_authorization_response(
  body: String,
) -> Result(DeviceAuthorizationResponse, errors.TidalError) {
  case json.parse(from: body, using: device_authorization_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_json.error_to_string(err),
      ))
  }
}

fn decode_oauth_token_response(
  body: String,
) -> Result(OauthToken, errors.TidalError) {
  case json.parse(from: body, using: oauth_token_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_json.error_to_string(err),
      ))
  }
}

pub type PollResult {
  PollResultContinue
  PollResultSuccess(String)
  PollResultError(errors.TidalError)
}

fn poll_http_request(
  config: Config,
  device_authorization_response: DeviceAuthorizationResponse,
  sender: tidal_http.Client,
) -> PollResult {
  let req =
    tidal_api.exchange_device_code_for_token(
      config.client_id,
      config.client_secret,
      device_authorization_response.device_code,
    )

  case sender(req) {
    Ok(response) -> {
      case response.status {
        400 -> PollResultContinue
        200 -> PollResultSuccess(response.body)
        status -> PollResultContinue
      }
    }
    Error(err) -> PollResultError(err)
  }
}

fn do_poll_device_authorization(
  remaining: Int,
  interval: Int,
  config: Config,
  device_authorization: DeviceAuthorizationResponse,
  sender: tidal_http.Client,
) -> Result(OauthToken, errors.TidalError) {
  case poll_http_request(config, device_authorization, sender) {
    PollResultSuccess(body) -> {
      decode_oauth_token_response(body)
    }
    PollResultContinue -> {
      case remaining <= 0 {
        True -> Error(errors.TidalDeviceAuthorizationExpiredError)
        False -> {
          process.sleep(interval * 1000)
          do_poll_device_authorization(
            remaining - interval,
            interval,
            config,
            device_authorization,
            sender,
          )
        }
      }
    }
    PollResultError(err) -> Error(err)
  }
}
