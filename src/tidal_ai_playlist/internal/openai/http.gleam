import gleam/http
import gleam/http/request
import gleam/json

import tidal_ai_playlist/internal/openai/config
import tidal_ai_playlist/internal/openai/types

const host = "api.openai.com"

const responses_path = "/v1/responses"

pub fn build_request(
  input: List(types.ResponsesInput),
  config: config.Config,
) -> request.Request(String) {
  let body =
    json.object([
      #("model", json.string(config.model_to_string(config.model))),
      #("instructions", json.string(config.instructions)),
      #("input", encode_responses_input(input)),
    ])
    |> json.to_string

  request.new()
  |> request.set_scheme(http.Https)
  |> request.set_host(host)
  |> request.set_path(responses_path)
  |> request.set_method(http.Post)
  |> request.prepend_header("Authorization", "Bearer " <> config.api_key)
  |> request.prepend_header("Content-Type", "application/json")
  |> request.set_body(body)
}

fn encode_responses_input(input: List(types.ResponsesInput)) -> json.Json {
  json.array(input, fn(x) {
    json.object([
      #("role", json.string(x.role)),
      #("content", json.string(x.content)),
    ])
  })
}
