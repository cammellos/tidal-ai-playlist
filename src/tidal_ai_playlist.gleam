import envoy
import gleam/io
import gleam/option
import gleam/result
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/openai
import tidal_ai_playlist/internal/tidal

pub fn main() -> Nil {
  //generate_playlist("Suggest some modern jazz albums")
  let playlist =
    Playlist([Song(artist: "The beatles", title: "Yellow submarine")])
  create_playlist(playlist)
  Nil
}

pub type Song {
  Song(artist: String, title: String)
}

pub type Playlist {
  Playlist(songs: List(Song))
}

fn create_playlist(playlist: Playlist) {
  let client_id = result.unwrap(envoy.get("TIDAL_CLIENT_ID"), "")
  let client_secret = result.unwrap(envoy.get("TIDAL_CLIENT_SECRET"), "")
  let config = tidal.Config(client_id: client_id, client_secret: client_secret)
  case tidal.login(config) {
    Ok(_) -> io.println("OK")
    Error(err) -> handle_tidal_error(err)
  }
}

fn handle_tidal_error(err: errors.TidalError) {
  case err {
    errors.HttpError(reason) -> io.println("Http Error: " <> reason)
    errors.ParseError(reason) -> io.println("Parse Error: " <> reason)
    errors.OtherError(reason) -> io.println("Other Error: " <> reason)
    errors.TidalDeviceAuthorizationExpiredError ->
      io.println("Device Authorization Expired")
  }
}

fn generate_playlist(input: String) -> Result(String, String) {
  let instructions =
    "You are a helpful music recommendation assistant. Suggest music based on the user's preferences, mood, or context. Provide a mix of well-known tracks and hidden gems, with short explanations. Please provide playlist in an importable format, so no markdown, just artist and song title. No extra text."
  let api_key = result.unwrap(envoy.get("OPENAI_API_KEY"), "")
  let config =
    openai.Config(
      model: openai.Gpt4o,
      api_key: api_key,
      instructions: instructions,
    )
  case openai.responses(input, config, option.None) {
    Ok(openai.Response(_, [openai.Output(_, [openai.Content(text), ..]), ..])) -> {
      io.println(text)
      Ok(text)
    }

    Error(errors.HttpError(reason)) -> {
      io.println("Http request error: " <> reason)
      Error(reason)
    }
    Error(errors.ParseError(reason)) -> {
      io.println("Parse error: " <> reason)
      Error(reason)
    }
    Error(errors.OtherError(reason)) -> {
      io.println("Unknown error: " <> reason)
      Error(reason)
    }
    _ -> {
      io.println("data malformed")
      Error("data malformed")
    }
  }
}
