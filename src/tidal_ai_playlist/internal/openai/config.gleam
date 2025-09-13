import gleam/option

import tidal_ai_playlist/internal/http

pub type Config {
  Config(
    model: Model,
    instructions: String,
    api_key: String,
    http_client: option.Option(http.Client),
  )
}

pub type Model {
  Gpt4o
  Gpt4oMini
  Gpt35Turbo
  Other(String)
}

pub fn model_to_string(model: Model) -> String {
  case model {
    Gpt4o -> "gpt-4o"
    Gpt4oMini -> "gpt-4o-mini"
    Gpt35Turbo -> "gpt-3.5-turbo"
    Other(name) -> name
  }
}
