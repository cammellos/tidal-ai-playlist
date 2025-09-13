import gleam/option
import gleeunit
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
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

pub fn responses_returns_decoded_response_test() {
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

  let fake_sender: http.Client = fn(_req) {
    Ok(http.HttpResponse(status: 200, body: fake_body, etag: ""))
  }

  let config = openai.Config(openai.Gpt4o, "instructions", "dummy_api_key", option.Some(fake_sender))

  let response =
    openai.responses([openai.ResponsesInput(role: "user", content: "input text")], config)
  assert response
    == Ok(
      openai.Response(id: "resp1", output: [
        openai.Output(id: "out1", content: [openai.Content("Hello world!")]),
      ]),
    )
}

pub fn responses_malformed_test() {
  let fake_body = "malformed"

  let fake_sender: http.Client = fn(_req) {
    Ok(http.HttpResponse(status: 200, body: fake_body, etag: ""))
  }

  let config = openai.Config(openai.Gpt4o, "instructions", "dummy_api_key", option.Some(fake_sender))

  let response =
    openai.responses([openai.ResponsesInput(role: "user", content: "input text")], config)
  assert Error(errors.ParseError("Failed to parse json: unexpected byte 0x6D"))
    == response
}

pub fn responses_propagates_http_errors_test() {
  let fake_sender: http.Client = fn(_req) {
    Error(errors.HttpError("network down"))
  }
  let config = openai.Config(openai.Gpt4o, "instructions", "dummy_api_key", option.Some(fake_sender))

  let response = openai.responses([openai.ResponsesInput(role: "user", content: "input text")], config)
  assert response == Error(errors.HttpError("network down"))
}

pub fn ask_returns_only_text_test() {
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

  let fake_sender: http.Client = fn(_req) {
    Ok(http.HttpResponse(status: 200, body: fake_body, etag: ""))
  }

  let config = openai.Config(openai.Gpt4o, "instructions", "dummy_api_key", option.Some(fake_sender))

  let response =
    openai.ask([openai.ResponsesInput(role: "user", content: "input text")], config)
  assert response
    == Ok("Hello world!")
}

pub fn ask_malformed_test() {
  let fake_body = "malformed"

  let fake_sender: http.Client = fn(_req) {
    Ok(http.HttpResponse(status: 200, body: fake_body, etag: ""))
  }

  let config = openai.Config(openai.Gpt4o, "instructions", "dummy_api_key", option.Some(fake_sender))

  let response =
    openai.ask([openai.ResponsesInput(role: "user", content: "input text")], config)
  assert Error(errors.ParseError("Failed to parse json: unexpected byte 0x6D"))
    == response
}

pub fn ask_propagates_http_errors_test() {
  let fake_sender: http.Client = fn(_req) {
    Error(errors.HttpError("network down"))
  }
  let config = openai.Config(openai.Gpt4o, "instructions", "dummy_api_key", option.Some(fake_sender))

  let response = openai.ask([openai.ResponsesInput(role: "user", content: "input text")], config)
  assert response == Error(errors.HttpError("network down"))
}
