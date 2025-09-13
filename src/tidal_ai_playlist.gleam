import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import input
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/openai/api as openai_api
import tidal_ai_playlist/internal/openai/config as openai_config
import tidal_ai_playlist/internal/openai/types as openai_types
import tidal_ai_playlist/internal/tidal/api as tidal_api
import tidal_ai_playlist/internal/tidal/config as tidal_config
import tidal_ai_playlist/internal/tidal/types as tidal_types

const instructions = "You are a music recommendation assistant.

Given the user's input, create a playlist as instructed. Include only artist and song title, tab-separated (TSV format).

Do not include markdown, commentary, or explanations.
Wrap the playlist between exactly these separator lines:
=====
(playlist)
====="

pub fn main() -> Nil {
  //create_playlist()
  let assert Ok(playlist) = interactive_playlist()
  let assert Ok(tidal_config) = load_tidal_config()
  create_tidal_playlist_from_openai(tidal_config, playlist)
  Nil
}

fn load_tidal_config() -> Result(tidal_types.Config, errors.TidalAPIError) {
  let refresh_token =
    "***REMOVED***"
  let client_id = "***REMOVED***"
  let client_secret = "***REMOVED***"

  let config =
    tidal_config.new(client_id, client_secret)
    |> tidal_config.add_refresh_token(refresh_token)

  use access_token_response <- result.try(tidal_api.refresh_token(config))

  config
  |> tidal_config.add_access_token(access_token_response.access_token)
  |> tidal_config.add_user_id(access_token_response.user_id)
  |> Ok
}

pub fn interactive_playlist() -> Result(Playlist, errors.TidalAPIError) {
  let api_key = result.unwrap(envoy.get("OPENAI_API_KEY"), "")
  let config =
    openai_config.Config(
      model: openai_config.Gpt4o,
      api_key: api_key,
      instructions: instructions,
      http_client: option.None,
    )

  // Ask initial prompt
  io.println("What music would you like to listen to today?")
  let assert Ok(first_prompt) = input.input(prompt: "> ")

  // Start recursion with initial chat history
  interactive_loop(config, [openai_types.ResponsesInput("user", first_prompt)])
}

fn interactive_loop(
  config: openai_config.Config,
  messages: List(openai_types.ResponsesInput),
) -> Result(Playlist, errors.TidalAPIError) {
  // Ask OpenAI for a playlist suggestion
  case openai_api.ask(messages, config) {
    Ok(reply) -> {
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
              openai_types.ResponsesInput("assistant", reply),
              openai_types.ResponsesInput("user", new_prompt),
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

fn create_playlist() {
  let client_id = result.unwrap(envoy.get("TIDAL_CLIENT_ID"), "")
  let client_secret = result.unwrap(envoy.get("TIDAL_CLIENT_SECRET"), "")
  let config = tidal_config.new(client_id, client_secret)
  case tidal_api.login(config) {
    Ok(_) -> io.println("OK")
    Error(err) -> errors.print_error(err)
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
  config: tidal_types.Config,
  playlist: Playlist,
) -> Result(Nil, errors.TidalAPIError) {
  // 2. Create the playlist on Tidal
  use new_playlist <- result.try(tidal_api.create_playlist(
    config,
    playlist.title,
    playlist.description,
  ))
  io.println("SEARCHING")

  // 3. For each song in playlist.songs search Tidal and collect IDs
  let track_ids =
    playlist.songs
    |> list.map(fn(song) {
      // For each Song, try to search and return Result(Int, String)
      io.println("Searching for: " <> song.artist <> " " <> song.title)
      result.map(
        tidal_api.search_track(config, song.artist, song.title),
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
  use _ <- result.try(tidal_api.add_tracks_to_playlist(
    config,
    new_playlist.id,
    track_ids,
    new_playlist.etag,
  ))

  io.println(
    "Added " <> int.to_string(list.length(track_ids)) <> " tracks to playlist.",
  )
  Ok(Nil)
}
