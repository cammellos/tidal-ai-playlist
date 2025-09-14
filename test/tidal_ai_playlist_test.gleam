import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/otp/actor

import gleeunit

import tidal_ai_playlist
import tidal_ai_playlist/fixtures
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/types

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn run_test() {
  let assert Ok(http_actor) =
    actor.new(0)
    |> actor.on_message(handle_message)
    |> actor.start

  let assert Ok(input_actor) =
    actor.new(0)
    |> actor.on_message(handle_message)
    |> actor.start

  let dependencies =
    tidal_ai_playlist.Dependencies(
      get_env_fn: get_env_fn,
      http_client: http_client(http_actor),
      input_fn: get_input_fn(input_actor),
      output_fn: fn(_) { Nil },
    )

  let assert Ok(playlist) = tidal_ai_playlist.run(dependencies)
  assert playlist
    == types.Playlist(
      songs: [
        types.Track("Artist One", "Song One"),
        types.Track("Artist Two", "Song Two"),
        types.Track("Artist Three", "Song Three"),
      ],
      title: "some title",
      description: "some description",
    )
}

fn get_env_fn(key: String) -> Result(String, Nil) {
  case key {
    "OPENAI_API_KEY" -> Ok("openai-api-key")
    "TIDAL_CLIENT_ID" -> Ok("tidal-client-id")
    "TIDAL_CLIENT_SECRET" -> Ok("tidal-client-secret")
    _ -> Error(Nil)
  }
}

fn get_input_fn(
  actor: actor.Started(Subject(Message)),
) -> fn(String) -> Result(String, Nil) {
  fn(_) -> Result(String, Nil) {
    actor.send(actor.data, Hit)
    case actor.call(actor.data, waiting: 10, sending: Get) {
      1 -> Ok("some music")
      2 -> Ok("n")
      3 -> Ok("some changes")
      4 -> Ok("y")
      5 -> Ok("some title")
      6 -> Ok("some description")
      _ -> Error(Nil)
    }
  }
}

fn http_client(
  actor: actor.Started(Subject(Message)),
) -> fn(request.Request(String)) -> Result(http.HttpResponse, a) {
  fn(req: request.Request(String)) -> Result(http.HttpResponse, a) {
    case req.path {
      "/v1/oauth2/device_authorization" ->
        build_response(fixtures.device_authorization_response, 200)
      "/v1/oauth2/token" -> {
        actor.send(actor.data, Hit)
        case actor.call(actor.data, waiting: 10, sending: Get) {
          3 -> build_response(fixtures.refresh_token_response, 200)
          2 ->
            build_response(fixtures.device_authorization_success_response, 200)
          _ ->
            build_response(fixtures.device_authorization_pending_response, 400)
        }
      }
      "/v1/responses" -> build_response(fixtures.responses_response, 200)
      "/v1/users/1/playlists" ->
        build_response(fixtures.create_playlist_response, 200)

      "/v1/playlists/3758b8a5-dcbd-46f8-8f36-6869b46b7e5b/items" ->
        build_response(fixtures.add_tracks_to_playlist_response, 200)
      _ -> Ok(http.HttpResponse(status: 404, body: "", etag: ""))
    }
  }
}

fn build_response(body: String, status: Int) -> Result(http.HttpResponse, a) {
  Ok(http.HttpResponse(status: status, body: body, etag: "100"))
}

pub fn handle_message(state: Int, message: Message) -> actor.Next(Int, Message) {
  case message {
    Hit -> {
      let state = state + 1
      actor.continue(state)
    }
    Get(reply) -> {
      actor.send(reply, state)
      actor.continue(state)
    }
  }
}

pub type Message {
  Hit
  Get(Subject(Int))
}
