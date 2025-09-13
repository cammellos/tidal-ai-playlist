import gleam/option

import youid/uuid

import tidal_ai_playlist/internal/http

pub type Config {
  Config(
    client_id: String,
    client_secret: String,
    user_id: option.Option(Int),
    refresh_token: option.Option(String),
    access_token: option.Option(String),
    session_id: String,
    http_client: option.Option(http.Client),
  )
}

pub fn new(client_id: String, client_secret: String) -> Config {
  Config(
    client_id: client_id,
    client_secret: client_secret,
    session_id: uuid.v4_string(),
    user_id: option.None,
    refresh_token: option.None,
    access_token: option.None,
    http_client: option.None,
  )
}

pub fn add_refresh_token(config: Config, refresh_token: String) -> Config {
  Config(..config, refresh_token: option.Some(refresh_token))
}

pub fn add_access_token(config: Config, access_token: String) -> Config {
  Config(..config, access_token: option.Some(access_token))
}

pub fn add_user_id(config: Config, user_id: Int) -> Config {
  Config(..config, user_id: option.Some(user_id))
}
