import gleam/json
import gleam/option
import gleam/result

import envoy
import simplifile
import youid/uuid

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/option as tidal_ai_playlist_option
import tidal_ai_playlist/internal/tidal/decoders
import tidal_ai_playlist/internal/tidal/types

pub fn new(client_id: String, client_secret: String) -> types.Config {
  types.Config(
    client_id: client_id,
    client_secret: client_secret,
    session_id: uuid.v4_string(),
    user_id: option.None,
    refresh_token: option.None,
    access_token: option.None,
    http_client: option.None,
  )
}

pub fn from_env() -> Result(types.Config, errors.TidalAIPlaylistError) {
  let client_id_result = envoy.get("TIDAL_CLIENT_ID")
  let client_secret_result = envoy.get("TIDAL_CLIENT_SECRET")

  case #(client_id_result, client_secret_result) {
    #(Ok(client_id), Ok(client_secret)) -> Ok(new(client_id, client_secret))
    _ -> Error(errors.TidalCredentialsMissing)
  }
}

pub fn from_file(filepath: String) -> Result(types.Config, errors.TidalAIPlaylistError) {
  let file_result = simplifile.read(from: filepath)
  case file_result {
    Ok(config_json) -> decoders.decode_config(config_json)
    Error(err) -> Error(errors.TidalReadingConfigError)
  }
}

pub fn to_file(
  config: types.Config,
  filepath: String,
) -> Result(types.Config, errors.TidalAIPlaylistError) {
  use refresh_token <- result.try(tidal_ai_playlist_option.from_option(
    config.refresh_token,
    errors.TidalCredentialsMissing,
  ))

  use user_id <- result.try(tidal_ai_playlist_option.from_option(
    config.user_id,
    errors.TidalCredentialsMissing,
  ))

  let json_config =
    json.to_string(
      json.object([
        #("client_id", json.string(config.client_id)),
        #("client_secret", json.string(config.client_secret)),
        #("refresh_token", json.string(refresh_token)),
        #("user_id", json.int(user_id)),
      ]),
    )
  case simplifile.write(contents: json_config, to: filepath) {
    Ok(_) -> Ok(config)
    Error(_) -> Error(errors.TidalWritingConfigError)
  }
}

pub fn add_refresh_token(
  config: types.Config,
  refresh_token: String,
) -> types.Config {
  types.Config(..config, refresh_token: option.Some(refresh_token))
}

pub fn add_access_token(
  config: types.Config,
  access_token: String,
) -> types.Config {
  types.Config(..config, access_token: option.Some(access_token))
}

pub fn add_user_id(config: types.Config, user_id: Int) -> types.Config {
  types.Config(..config, user_id: option.Some(user_id))
}

pub fn add_http_client(
  config: types.Config,
  client: http.Client,
) -> types.Config {
  types.Config(..config, http_client: option.Some(client))
}
