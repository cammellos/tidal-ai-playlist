import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option
import gleam/string

const host = "api.openai.com"

const responses_path = "/v1/responses"

pub type Config {
  Config(model: Model, instructions: String, api_key: String)
}

pub type OpenAIError {
  HttpError(String)
  ParseError(String)
  OtherError(String)
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

pub type Sender =
  fn(request.Request(String)) -> Result(String, OpenAIError)

pub fn responses(
  input: String,
  config: Config,
  sender: option.Option(Sender),
) -> Result(Response, OpenAIError) {
  let actual_sender = option.unwrap(sender, default_sender)
  responses_with_sender(input, config, actual_sender)
}

pub fn responses_with_sender(
  input: String,
  config: Config,
  sender: Sender,
) -> Result(Response, OpenAIError) {
  let req = build_request(input, config)

  case sender(req) {
    Ok(body) -> decode_response(body)
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

fn default_sender(req: request.Request(String)) -> Result(String, OpenAIError) {
  case httpc.send(req) {
    Ok(resp) -> Ok(resp.body)
    Error(err) -> Error(HttpError("Failed: " <> http_error_to_string(err)))
  }
}

fn http_error_to_string(error: httpc.HttpError) -> String {
  case error {
    httpc.InvalidUtf8Response -> "invalid utf8 response"
    httpc.ResponseTimeout -> "response timeout"
    httpc.FailedToConnect(_, _) -> "failed to connect"
  }
}

fn json_error_to_string(error: json.DecodeError) -> String {
  case error {
    json.UnexpectedEndOfInput -> "unexpected end of input"
    json.UnexpectedByte(byte) -> "unexpected byte " <> byte
    json.UnexpectedSequence(seq) -> "unexpected sequence " <> seq
    json.UnableToDecode(errors) ->
      "unable to decode "
      <> string.join(list.map(errors, decode_error_to_string), ",")
  }
}

fn decode_response(body: String) -> Result(Response, OpenAIError) {
  case json.parse(from: body, using: response_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(ParseError("Failed to parse json: " <> json_error_to_string(err)))
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

fn decode_error_to_string(error: decode.DecodeError) -> String {
  case error {
    decode.DecodeError(expected, found, path) ->
      "expected "
      <> expected
      <> " found "
      <> found
      <> " path "
      <> string.join(path, "-->")
  }
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
