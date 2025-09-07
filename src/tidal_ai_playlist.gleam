import envoy
import gleam/io
import gleam/option
import gleam/result
import tidal_ai_playlist/internal/openai

pub fn main() -> Nil {
  let instructions =
    "You are a helpful music recommendation assistant. Suggest music based on the user's preferences, mood, or context. Provide a mix of well-known tracks and hidden gems, with short explanations. Please provide playlist in an importable format, so no markdown, just artist and song title. No extra text."
  let input = "Suggest some modern jazz albums"
  let api_key = result.unwrap(envoy.get("OPENAI_API_KEY"), "")
  let config =
    openai.Config(
      model: openai.Gpt4o,
      api_key: api_key,
      instructions: instructions,
    )
  case openai.responses(input, config, option.None) {
    Ok(openai.Response(_, [openai.Output(_, [openai.Content(text), ..]), ..])) ->
      io.println(text)

    Error(openai.HttpError(reason)) ->
      io.println("Http request error: " <> reason)
    Error(openai.ParseError(reason)) -> io.println("Parse error: " <> reason)
    Error(openai.OtherError(reason)) -> io.println("Unknown error: " <> reason)
    _ -> io.println("data malformed")
  }
}
