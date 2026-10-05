import gleam/option

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http

pub const playlist_instructions = "You are a music recommendation assistant.

Given the user's input, create a playlist as instructed. Include only artist and song title, tab-separated (TSV format).

Do not include markdown, commentary, or explanations.
Wrap the playlist between exactly these separator lines:
=====
(playlist)
====="

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

pub fn from_env(
  instructions,
  get_env_fn: fn(String) -> Result(String, Nil),
) -> Result(Config, errors.TidalAIPlaylistError) {
  case get_env_fn("OPENAI_API_KEY") {
    Ok(openai_api_key) ->
      Ok(Config(
        model: Gpt4o,
        api_key: openai_api_key,
        instructions: instructions,
        http_client: option.Some(http.default_client),
      ))
    _ -> Error(errors.OpenAICredentialsMissing)
  }
}

pub fn add_http_client(config, client: http.Client) -> Config {
  Config(..config, http_client: option.Some(client))
}
