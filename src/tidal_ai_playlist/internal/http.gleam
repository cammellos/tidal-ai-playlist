import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import tidal_ai_playlist/internal/errors

pub type Sender =
  fn(request.Request(String)) -> Result(HttpResponse, errors.TidalError)

pub fn error_to_string(error: httpc.HttpError) -> String {
  case error {
    httpc.InvalidUtf8Response -> "invalid utf8 response"
    httpc.ResponseTimeout -> "response timeout"
    httpc.FailedToConnect(_, _) -> "failed to connect"
  }
}

pub type HttpResponse {
  HttpResponse(status: Int, body: String)
}

pub fn default_sender(
  req: request.Request(String),
) -> Result(HttpResponse, errors.TidalError) {
  case httpc.send(req) {
    Ok(resp) -> Ok(HttpResponse(status: resp.status, body: resp.body))
    Error(err) -> Error(errors.HttpError("Failed: " <> error_to_string(err)))
  }
}
