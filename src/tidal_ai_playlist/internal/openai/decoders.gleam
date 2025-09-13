import gleam/dynamic/decode
import gleam/json

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/json as tidal_json
import tidal_ai_playlist/internal/openai/types

pub fn decode_response(
  body: String,
) -> Result(types.Response, errors.TidalAPIError) {
  case json.parse(from: body, using: response_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_json.error_to_string(err),
      ))
  }
}

fn content_decoder() -> decode.Decoder(types.Content) {
  {
    use text <- decode.field("text", decode.string)
    decode.success(types.Content(text: text))
  }
}

fn output_decoder() -> decode.Decoder(types.Output) {
  {
    use content <- decode.field("content", decode.list(content_decoder()))
    use id <- decode.field("id", decode.string)
    decode.success(types.Output(id: id, content: content))
  }
}

fn response_decoder() -> decode.Decoder(types.Response) {
  {
    use id <- decode.field("id", decode.string)
    use output <- decode.field("output", decode.list(output_decoder()))
    decode.success(types.Response(id: id, output: output))
  }
}
