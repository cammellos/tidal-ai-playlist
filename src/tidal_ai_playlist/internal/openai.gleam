import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleam/option
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http as tidal_http
import tidal_ai_playlist/internal/json as tidal_json

const host = "api.openai.com"

const responses_path = "/v1/responses"

pub type Config {
  Config(model: Model, instructions: String, api_key: String)
}

pub type Model {
  Gpt4o
  Gpt4oMini
  Gpt35Turbo
  Other(String)
}

pub type Content {
  Content(text: String)
}

pub type Output {
  Output(id: String, content: List(Content))
}

pub type Response {
  Response(id: String, output: List(Output))
}

pub fn responses(
  input: String,
  config: Config,
  sender: option.Option(tidal_http.Sender),
) -> Result(Response, errors.TidalError) {
  let actual_sender = option.unwrap(sender, tidal_http.default_sender)
  responses_with_sender(input, config, actual_sender)
}

pub fn responses_with_sender(
  input: String,
  config: Config,
  sender: tidal_http.Sender,
) -> Result(Response, errors.TidalError) {
  let req = build_request(input, config)

  case sender(req) {
    Ok(response) -> decode_response(response.body)
    Error(err) -> Error(err)
  }
}

pub fn model_to_string(model: Model) -> String {
  case model {
    Gpt4o -> "gpt-4o"
    Gpt4oMini -> "gpt-4o-mini"
    Gpt35Turbo -> "gpt-3.5-turbo"
    Other(name) -> name
  }
}

fn decode_response(body: String) -> Result(Response, errors.TidalError) {
  case json.parse(from: body, using: response_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_json.error_to_string(err),
      ))
  }
}

fn build_request(input: String, config: Config) -> request.Request(String) {
  let body =
    json.object([
      #("model", json.string(model_to_string(config.model))),
      #("instructions", json.string(config.instructions)),
      #("input", json.string(input)),
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

fn content_decoder() -> decode.Decoder(Content) {
  {
    use text <- decode.field("text", decode.string)
    decode.success(Content(text: text))
  }
}

fn output_decoder() -> decode.Decoder(Output) {
  {
    use content <- decode.field("content", decode.list(content_decoder()))
    use id <- decode.field("id", decode.string)
    decode.success(Output(id: id, content: content))
  }
}

fn response_decoder() -> decode.Decoder(Response) {
  {
    use id <- decode.field("id", decode.string)
    use output <- decode.field("output", decode.list(output_decoder()))
    decode.success(Response(id: id, output: output))
  }
}
