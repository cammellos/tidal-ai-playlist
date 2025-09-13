import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http as tidal_http
import tidal_ai_playlist/internal/json as tidal_json

const host = "api.openai.com"

const responses_path = "/v1/responses"

pub type Config {
  Config(
    model: Model,
    instructions: String,
    api_key: String,
    http_client: option.Option(tidal_http.Client),
  )
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

pub type ResponsesInput {
  ResponsesInput(role: String, content: String)
}

pub fn responses(
  input: List(ResponsesInput),
  config: Config,
) -> Result(Response, errors.TidalAPIError) {
  let http_client = option.unwrap(config.http_client, tidal_http.default_client)
  let req = build_request(input, config)
  case http_client(req) {
    Ok(response) -> decode_response(response.body)
    Error(err) -> Error(err)
  }
}

pub fn ask(
  input: List(ResponsesInput),
  config: Config,
) -> Result(String, errors.TidalAPIError) {
  use response <- result.try(responses(input, config))
  extract_text(response)
}

pub fn model_to_string(model: Model) -> String {
  case model {
    Gpt4o -> "gpt-4o"
    Gpt4oMini -> "gpt-4o-mini"
    Gpt35Turbo -> "gpt-3.5-turbo"
    Other(name) -> name
  }
}

fn encode_responses_input(input: List(ResponsesInput)) -> json.Json {
  json.array(input, fn(x) {
    json.object([
      #("role", json.string(x.role)),
      #("content", json.string(x.content)),
    ])
  })
}

fn decode_response(body: String) -> Result(Response, errors.TidalAPIError) {
  case json.parse(from: body, using: response_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_json.error_to_string(err),
      ))
  }
}

fn build_request(
  input: List(ResponsesInput),
  config: Config,
) -> request.Request(String) {
  let body =
    json.object([
      #("model", json.string(model_to_string(config.model))),
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

fn extract_text(response: Response) -> Result(String, errors.TidalAPIError) {
  case response {
    Response(_, [Output(_, [Content(text), ..]), ..]) -> Ok(text)

    _ ->
      Error(errors.UnexpectedResponseFormatError(
        "OpenAI response is not the expected format",
      ))
  }
}
