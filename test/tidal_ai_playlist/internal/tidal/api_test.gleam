import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/otp/actor

import tidal_ai_playlist/fixtures
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/tidal/api
import tidal_ai_playlist/internal/tidal/config
import tidal_ai_playlist/internal/tidal/types

pub fn login_error_test() {
  let assert Ok(actor) =
    actor.new(0)
    |> actor.on_message(handle_message)
    |> actor.start

  let client = fn(req: request.Request(String)) -> Result(
    http.HttpResponse,
    errors.TidalAIPlaylistError,
  ) {
    case req.path {
      "/v1/oauth2/device_authorization" ->
        Ok(http.HttpResponse(
          status: 200,
          body: fixtures.device_authorization_response,
          etag: "100",
        ))
      "/v1/oauth2/token" -> {
        actor.send(actor.data, Hit)
        case actor.call(actor.data, waiting: 10, sending: Get) {
          2 ->
            Ok(http.HttpResponse(
              status: 200,
              body: fixtures.device_authorization_success_response,
              etag: "100",
            ))
          _ ->
            Ok(http.HttpResponse(
              status: 400,
              body: fixtures.device_authorization_pending_response,
              etag: "100",
            ))
        }
      }
      _ -> Error(errors.HttpError("failed"))
    }
  }

  let config = dummy_config() |> config.add_http_client(client)
  assert Ok(types.OauthToken("access-token", "refresh-token", 43_200, 1))
    == api.login(config)
}

pub fn refresh_token_missing_test() {
  let result = api.refresh_token(dummy_config())
  assert result == Error(errors.TidalRefreshTokenMissing)
}

pub fn refresh_token_test() {
  let client = build_client(fixtures.refresh_token_response)
  let config =
    dummy_config()
    |> config.add_refresh_token("refresh-token")
    |> config.add_http_client(client)

  assert Ok(types.RefreshTokenResponse("access-token", 1))
    == api.refresh_token(config)
}

pub fn create_playlist_missing_token_test() {
  let result = api.create_playlist(dummy_config(), "title", "desc")
  assert result == Error(errors.TidalAccessTokenMissing)
}

pub fn create_playlist_test() {
  let client = build_client(fixtures.create_playlist_response)
  let config = dummy_config_with_tokens() |> config.add_http_client(client)
  assert Ok(types.CreatePlaylistResponse(
      "3758b8a5-dcbd-46f8-8f36-6869b46b7e5b",
      "100",
    ))
    == api.create_playlist(config, "title", "desc")
}

pub fn search_track_missing_token_test() {
  let result =
    api.search_track(
      dummy_config(),
      "captain beefheart",
      "moonlight on vermont",
    )
  assert result == Error(errors.TidalAccessTokenMissing)
}

pub fn search_track_test() {
  let client = build_client(fixtures.search_track_response)
  let config = dummy_config_with_tokens() |> config.add_http_client(client)

  assert Ok(types.SearchTrackResponse(81_930_885, "Moonlight On Vermont (Live)"))
    == api.search_track(config, "captain beefheart", "moonlight on vermontn")
}

pub fn add_tracks_to_playlist_missing_token_test() {
  let result =
    api.add_tracks_to_playlist(dummy_config(), "playlist", [1, 2], "etag")
  assert result == Error(errors.TidalAccessTokenMissing)
}

pub fn add_tracks_to_playlist_test() {
  let client = build_client(fixtures.add_tracks_to_playlist_response)
  let config =
    dummy_config()
    |> config.add_access_token("token")
    |> config.add_user_id(1)
    |> config.add_http_client(client)

  assert Ok(types.AddTracksToPlaylistResponse(1, [1, 2]))
    == api.add_tracks_to_playlist(config, "playlist", [1, 2], "etag")
}

fn dummy_config() -> types.Config {
  config.new("test", "test")
  |> config.add_output_fn(fn(_) { Nil })
}

fn dummy_config_with_tokens() -> types.Config {
  dummy_config() |> config.add_access_token("token") |> config.add_user_id(1)
}

fn build_client(data) -> http.Client {
  fn(_req) { Ok(http.HttpResponse(status: 200, body: data, etag: "100")) }
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
