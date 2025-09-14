import gleam/option
import gleam/result

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/openai/config
import tidal_ai_playlist/internal/openai/decoders
import tidal_ai_playlist/internal/openai/http as openai_http
import tidal_ai_playlist/internal/openai/types

pub fn responses(
  input: List(types.ResponsesInput),
  config: config.Config,
) -> Result(types.Response, errors.TidalAIPlaylistError) {
  let http_client = option.unwrap(config.http_client, http.default_client)
  let req = openai_http.build_request(input, config)
  case http_client(req) {
    Ok(response) -> decoders.decode_response(response.body)
    Error(err) -> Error(err)
  }
}

pub fn ask(
  input: List(types.ResponsesInput),
  config: config.Config,
) -> Result(String, errors.TidalAIPlaylistError) {
  use response <- result.try(responses(input, config))
  extract_text(response)
}

fn extract_text(
  response: types.Response,
) -> Result(String, errors.TidalAIPlaylistError) {
  case response {
    types.Response(_, [types.Output(_, [types.Content(text), ..]), ..]) ->
      Ok(text)

    _ ->
      Error(errors.UnexpectedResponseFormatError(
        "OpenAI response is not the expected format",
      ))
  }
}
