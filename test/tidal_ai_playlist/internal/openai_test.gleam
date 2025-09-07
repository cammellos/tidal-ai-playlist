import gleam/option
import gleeunit
import tidal_ai_playlist/internal/openai

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn model_to_string_test() {
  assert openai.model_to_string(openai.Gpt4o) == "gpt-4o"
  assert openai.model_to_string(openai.Gpt4oMini) == "gpt-4o-mini"
  assert openai.model_to_string(openai.Gpt35Turbo) == "gpt-3.5-turbo"
  assert openai.model_to_string(openai.Other("custom-model")) == "custom-model"
}

pub fn responses_with_sender_returns_decoded_response_test() {
  let fake_body =
    "
      {
        \"id\": \"resp1\",
        \"output\": [
          {
            \"id\": \"out1\",
            \"content\": [
              {\"text\": \"Hello world!\"}
            ]
          }
        ]
      }
      "

  let fake_sender: openai.Sender = fn(_req) { Ok(fake_body) }

  let config = openai.Config(openai.Gpt4o, "instructions", "dummy_api_key")

  let response =
    openai.responses("input text", config, option.Some(fake_sender))
  assert response
    == Ok(
      openai.Response(id: "resp1", output: [
        openai.Output(id: "out1", content: [openai.Content("Hello world!")]),
      ]),
    )
}

pub fn responses_with_sender_malformed_test() {
  let fake_body = "malformed"

  let fake_sender: openai.Sender = fn(_req) { Ok(fake_body) }

  let config = openai.Config(openai.Gpt4o, "instructions", "dummy_api_key")

  let response =
    openai.responses("input text", config, option.Some(fake_sender))
  assert Error(openai.ParseError("Failed to parse json: unexpected byte 0x6D"))
    == response
}

pub fn responses_with_sender_propagates_http_errors_test() {
  let fake_sender: openai.Sender = fn(_req) {
    Error(openai.HttpError("network down"))
  }
  let config = openai.Config(openai.Gpt4o, "instructions", "dummy_api_key")

  let response = openai.responses_with_sender("input text", config, fake_sender)
  assert response == Error(openai.HttpError("network down"))
}
