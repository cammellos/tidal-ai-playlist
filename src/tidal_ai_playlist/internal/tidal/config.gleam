import gleam/option

import tidal_ai_playlist/internal/http

pub type Config {
  Config(
    client_id: String,
    client_secret: String,
    http_client: option.Option(http.Client),
  )
}
