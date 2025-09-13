import gleam/option
import gleam/result
import simplifile

import envoy
import youid/uuid

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
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

pub fn from_env() -> Result(types.Config, errors.TidalAPIError) {
  let client_id_result = envoy.get("TIDAL_CLIENT_ID")
  let client_secret_result = envoy.get("TIDAL_CLIENT_SECRET")

  case #(client_id_result, client_secret_result) {
    #(Ok(client_id), Ok(client_secret)) -> Ok(new(client_id, client_secret))
    _ -> Error(errors.TidalCredentialsMissing)
  }
}

pub fn from_file(filepath: String) -> Result(types.Config, errors.TidalAPIError) {
  let file_result = simplifile.read(from: filepath)
  case file_result {
    Ok(config_json) -> decoders.decode_config(config_json)
    Error(err) -> Error(errors.TidalReadingConfigError)
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
