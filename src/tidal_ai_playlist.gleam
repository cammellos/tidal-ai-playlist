import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import input
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/openai
import tidal_ai_playlist/internal/tidal
import tidal_ai_playlist/internal/tidal_api

const instructions = "You are a music recommendation assistant.

Given the user's input, create a playlist as instructed. Include only artist and song title, tab-separated (TSV format).

Do not include markdown, commentary, or explanations.
Wrap the playlist between exactly these separator lines:
=====
(playlist)
====="

pub fn main() -> Nil {
  let assert Ok(playlist) = interactive_playlist()
  //io.println("What would you like to listen to?")
  //let assert Ok(prompt) = input.input(prompt: "> ")
  //let assert Ok(playlist) = generate_playlist(prompt)
  let refresh_token =
    "***REMOVED***"
  let client_id = "***REMOVED***"
  let client_secret = "***REMOVED***"
  let session_id = "2dc6cd75-7c6f-4943-b7a6-5807ea8862ae"

  create_tidal_playlist_from_openai(
    client_id,
    client_secret,
    refresh_token,
    session_id,
    playlist,
  )
  Nil
}

pub fn interactive_playlist() -> Result(Playlist, errors.TidalAPIError) {
  let api_key = result.unwrap(envoy.get("OPENAI_API_KEY"), "")
  let config =
    openai.Config(
      model: openai.Gpt4o,
      api_key: api_key,
      instructions: instructions,
      http_client: option.None,
    )

  // Ask initial prompt
  io.println("What music would you like to listen to today?")
  let assert Ok(first_prompt) = input.input(prompt: "> ")

  // Start recursion with initial chat history
  interactive_loop(config, [openai.ResponsesInput("user", first_prompt)])
}

fn interactive_loop(
  config: openai.Config,
  messages: List(openai.ResponsesInput),
) -> Result(Playlist, errors.TidalAPIError) {
  // Ask OpenAI for a playlist suggestion
  case openai.responses(messages, config) {
    Ok(reply_response) -> {
      let reply = extract_text(reply_response)
      io.println("\nProposed Playlist:\n")
      io.println(reply)

      io.println("\nGenerate this playlist? (y/n)")
      let assert Ok(ans) = input.input(prompt: "> ")
      let trimmed = string.trim(ans)

      case trimmed {
        "y" -> {
          // Playlist accepted, ask for title/description
          io.println("What would you like to name the playlist?")
          let assert Ok(title) = input.input(prompt: "> ")
          io.println("What would you like to set for the description?")
          let assert Ok(description) = input.input(prompt: "> ")

          let songs = parse_playlist(reply)
          Ok(Playlist(songs: songs, title: title, description: description))
        }

        _ -> {
          // User wants a revision
          io.println("What would you like changed?")
          let assert Ok(new_prompt) = input.input(prompt: "> ")
          // Add both AI reply and new user prompt to context
          let new_messages =
            list.append(messages, [
              openai.ResponsesInput("assistant", reply),
              openai.ResponsesInput("user", new_prompt),
            ])
          interactive_loop(config, new_messages)
          // recursive call
        }
      }
    }

    Error(reason) -> {
      io.println("Error: ")
      Error(reason)
    }
  }
}

pub type Song {
  Song(artist: String, title: String)
}

pub type Playlist {
  Playlist(songs: List(Song), title: String, description: String)
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

fn handle_tidal_error(err: errors.TidalAPIError) {
  case err {
    errors.HttpError(reason) -> io.println("Http Error: " <> reason)
    errors.ParseError(reason) -> io.println("Parse Error: " <> reason)
    errors.OtherError(reason) -> io.println("Other Error: " <> reason)
    errors.TidalDeviceAuthorizationExpiredError ->
      io.println("Device Authorization Expired")
  }
}

fn extract_text(response: openai.Response) -> String {
  let assert openai.Response(
    _,
    [openai.Output(_, [openai.Content(text), ..]), ..],
  ) = response
  text
}

pub fn generate_playlist(input: String) -> Result(Playlist, String) {
  let api_key = result.unwrap(envoy.get("OPENAI_API_KEY"), "")
  let config =
    openai.Config(
      model: openai.Gpt4o,
      api_key: api_key,
      instructions: instructions,
      http_client: option.None,
    )
  case
    openai.responses(
      [openai.ResponsesInput(role: "user", content: input)],
      config,
    )
  {
    Ok(openai.Response(_, [openai.Output(_, [openai.Content(text), ..]), ..])) -> {
      io.println("What would you like to name the playlist?")
      let assert Ok(title) = input.input(prompt: "> ")
      io.println("What would you like to set for the description?")
      let assert Ok(description) = input.input(prompt: "> ")

      let songs = parse_playlist(text)
      Ok(Playlist(songs: songs, title: title, description: description))
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

fn parse_playlist(playlist: String) -> List(Song) {
  let separator = "======="
  io.println("Raw playlist:\n" <> playlist)

  // Extract only the part between the first and last separators
  let parts = string.split(playlist, separator)
  let inner = case parts {
    // If model returns: =============\n...\n============
    [_before, inner, ..] -> string.trim(inner)
    // If it returns only the content
    [only] -> string.trim(only)
    _ -> playlist
    // fallback
  }

  // Split lines and parse each safely
  string.split(inner, "\n")
  |> list.filter(fn(line) {
    let trimmed = string.trim(line)
    trimmed != "" && trimmed != separator
  })
  |> list.map(fn(line) {
    let fields = string.split(line, "\t")
    case fields {
      [artist, title] ->
        Song(artist: string.trim(artist), title: string.trim(title))
      _ -> {
        io.println("Skipping malformed line: " <> line)
        Song(artist: "", title: "")
      }
    }
  })
  |> list.filter(fn(song) { song.artist != "" && song.title != "" })
}

pub fn create_tidal_playlist_from_openai(
  client_id: String,
  client_secret: String,
  refresh_token: String,
  session_id: String,
  playlist: Playlist,
) -> Result(Nil, errors.TidalAPIError) {
  // 1. Refresh token
  use token <- result.try(tidal_api.do_refresh_token(
    client_id,
    client_secret,
    refresh_token,
  ))

  // 2. Create the playlist on Tidal
  use new_playlist <- result.try(tidal_api.do_create_playlist(
    token.user_id,
    playlist.title,
    playlist.description,
    token.access_token,
    session_id,
  ))
  io.println("SEARCHING")

  // 3. For each song in playlist.songs search Tidal and collect IDs
  let track_ids =
    playlist.songs
    |> list.map(fn(song) {
      // For each Song, try to search and return Result(Int, String)
      io.println("Searching for: " <> song.artist <> " " <> song.title)
      result.map(
        tidal_api.do_search_track(
          song.artist,
          song.title,
          token.access_token,
          session_id,
        ),
        fn(track) { track.id },
      )
    })
    |> list.filter_map(fn(r) {
      case r {
        Ok(id) -> Ok(id)
        Error(err) -> {
          io.println("Skipping ")
          Error(Nil)
        }
      }
    })
  list.map(track_ids, fn(x) { io.println(int.to_string(x)) })

  // 4. Add tracks to playlist
  use _ <- result.try(tidal_api.do_add_tracks_to_playlist(
    new_playlist.id,
    track_ids,
    token.access_token,
    session_id,
    new_playlist.etag,
  ))

  io.println(
    "Added " <> int.to_string(list.length(track_ids)) <> " tracks to playlist.",
  )
  Ok(Nil)
}
