import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/list
import gleam/result

import tidal_ai_playlist/internal/errors

pub type Client =
  fn(request.Request(String)) ->
    Result(HttpResponse, errors.TidalAIPlaylistError)

pub fn error_to_string(error: httpc.HttpError) -> String {
  case error {
    httpc.InvalidUtf8Response -> "invalid utf8 response"
    httpc.ResponseTimeout -> "response timeout"
    httpc.FailedToConnect(_, _) -> "failed to connect"
  }
}

pub type HttpResponse {
  HttpResponse(status: Int, body: String, etag: String)
}

pub fn default_client(
  req: request.Request(String),
) -> Result(HttpResponse, errors.TidalAIPlaylistError) {
  let response =
    httpc.configure()
    |> httpc.timeout(60_000)
    |> httpc.dispatch(req)
  case response {
    Ok(resp) -> {
      let etag =
        list.find_map(resp.headers, fn(pair) {
          let #(header, value) = pair
          case header {
            "etag" -> Ok(value)
            _ -> Error(Nil)
          }
        })
        |> result.unwrap("")
      Ok(HttpResponse(status: resp.status, body: resp.body, etag: etag))
    }
    Error(err) -> {
      Error(errors.HttpError("Failed: " <> error_to_string(err)))
    }
  }
}
