import gleam/dynamic/decode
import gleam/json

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/json as tidal_ai_playlist_json
import tidal_ai_playlist/internal/tidal/types

pub fn decode_device_authorization_response(
  body: String,
) -> Result(types.DeviceAuthorizationResponse, errors.TidalAPIError) {
  case json.parse(from: body, using: device_authorization_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_ai_playlist_json.error_to_string(err),
      ))
  }
}

pub fn decode_oauth_token_response(
  body: String,
) -> Result(types.OauthToken, errors.TidalAPIError) {
  case json.parse(from: body, using: oauth_token_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_ai_playlist_json.error_to_string(err),
      ))
  }
}

pub fn decode_refresh_token_response(
  body: String,
) -> Result(types.RefreshTokenResponse, errors.TidalAPIError) {
  case json.parse(from: body, using: refresh_token_response_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_ai_playlist_json.error_to_string(err),
      ))
  }
}

pub fn decode_create_playlist_response(
  body: String,
) -> Result(types.CreatePlaylistResponse, errors.TidalAPIError) {
  case json.parse(from: body, using: create_playlist_response_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) -> {
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_ai_playlist_json.error_to_string(err),
      ))
    }
  }
}

pub fn decode_search_track_response(
  body: String,
) -> Result(types.SearchTrackResponse, errors.TidalAPIError) {
  case json.parse(from: body, using: search_track_response_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) -> {
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_ai_playlist_json.error_to_string(err),
      ))
    }
  }
}

fn oauth_token_decoder() -> decode.Decoder(types.OauthToken) {
  {
    use access_token <- decode.field("access_token", decode.string)
    use refresh_token <- decode.field("refresh_token", decode.string)
    use expires_in <- decode.field("expires_in", decode.int)
    use user_id <- decode.field("user_id", decode.int)
    decode.success(types.OauthToken(
      access_token,
      refresh_token,
      expires_in,
      user_id,
    ))
  }
}

fn device_authorization_decoder() -> decode.Decoder(
  types.DeviceAuthorizationResponse,
) {
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

    decode.success(types.DeviceAuthorizationResponse(
      device_code: device_code,
      user_code: user_code,
      verification_uri: verification_uri,
      verification_uri_complete: verification_uri_complete,
      expires_in: expires_in,
      interval: interval,
    ))
  }
}

fn refresh_token_response_decoder() -> decode.Decoder(
  types.RefreshTokenResponse,
) {
  {
    use access_token <- decode.field("access_token", decode.string)
    use user_id <- decode.field("user_id", decode.int)
    decode.success(types.RefreshTokenResponse(
      access_token: access_token,
      user_id: user_id,
    ))
  }
}

fn create_playlist_response_decoder() -> decode.Decoder(
  types.CreatePlaylistResponse,
) {
  {
    use id <- decode.field("uuid", decode.string)
    decode.success(types.CreatePlaylistResponse(id: id, etag: ""))
  }
}

fn search_track_response_decoder() -> decode.Decoder(types.SearchTrackResponse) {
  {
    use top_hit <- decode.field("topHit", top_hit_decoder())
    decode.success(types.SearchTrackResponse(
      id: top_hit.id,
      title: top_hit.title,
    ))
  }
}

fn top_hit_decoder() -> decode.Decoder(types.TopHit) {
  {
    use top_hit <- decode.field("value", value_decoder())
    decode.success(top_hit)
  }
}

fn value_decoder() -> decode.Decoder(types.TopHit) {
  {
    use id <- decode.field("id", decode.int)
    use title <- decode.field("title", decode.string)
    decode.success(types.TopHit(id: id, title: title))
  }
}
