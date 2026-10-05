import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub type FavoriteKind {
  FavoriteTracks
  FavoriteAlbums
  FavoriteArtists
}

pub type Page {
  Page(limit: Int, offset: Int)
}

pub type Command {
  Interactive
  Help
  Login(output: String)
  Search(query: String, limit: Int)
  ListPlaylists(page: Page)
  PlaylistTracks(playlist_id: String, page: Page)
  Favorites(kind: FavoriteKind, page: Page)
  CreatePlaylist(title: String, description: String)
  AddTracks(playlist_id: String, track_ids: List(Int))
  Generate(prompt: String, title: option.Option(String), description: String)
}

pub const usage = "Usage: tidal-ai-playlist [command]

With no command, runs the interactive AI playlist flow.
Every other command prints JSON on stdout.

Commands:
  login --output <file>                      Device login; writes {refresh_token, user_id} to <file>
  search <query> [--limit N]                 Search tracks (default limit 10)
  list-playlists [--limit N] [--offset N]    Your playlists
  playlist-tracks <uuid> [--limit N] [--offset N]
  favorites [tracks|albums|artists] [--limit N] [--offset N]
  create-playlist <title> [--description D]
  add <uuid> <track-id>...                   Add tracks to a playlist
  generate <prompt> [--title T] [--description D]
                                             Ask OpenAI for tracks and create a playlist
  help

Environment:
  TIDAL_CLIENT_ID, TIDAL_CLIENT_SECRET       Required
  TIDAL_REFRESH_TOKEN, TIDAL_USER_ID         Saved login (from `login`)
  OPENAI_API_KEY                             For `generate` and the interactive flow"

const default_limit = 50

pub fn parse(args: List(String)) -> Result(Command, String) {
  use #(positional, flags) <- result.try(split_flags(args, [], dict.new()))
  case positional {
    [] -> Ok(Interactive)
    ["help"] | ["--help"] | ["-h"] -> Ok(Help)
    ["login"] ->
      case dict.get(flags, "output") {
        Ok(output) -> Ok(Login(output))
        Error(_) -> Error("login needs --output <file>")
      }
    ["search", ..words] if words != [] -> {
      use limit <- result.try(int_flag(flags, "limit", 10))
      Ok(Search(string.join(words, " "), limit))
    }
    ["list-playlists"] -> result.map(page(flags), ListPlaylists)
    ["playlist-tracks", playlist_id] ->
      result.map(page(flags), PlaylistTracks(playlist_id, _))
    ["favorites"] -> result.map(page(flags), Favorites(FavoriteTracks, _))
    ["favorites", kind] -> {
      use kind <- result.try(favorite_kind(kind))
      result.map(page(flags), Favorites(kind, _))
    }
    ["create-playlist", ..words] if words != [] ->
      Ok(CreatePlaylist(
        string.join(words, " "),
        dict.get(flags, "description") |> result.unwrap(""),
      ))
    ["add", playlist_id, ..track_ids] if track_ids != [] -> {
      use track_ids <- result.try(
        list.try_map(track_ids, fn(id) {
          int.parse(id) |> result.replace_error("not a track id: " <> id)
        }),
      )
      Ok(AddTracks(playlist_id, track_ids))
    }
    ["generate", ..words] if words != [] ->
      Ok(Generate(
        string.join(words, " "),
        dict.get(flags, "title") |> option.from_result,
        dict.get(flags, "description") |> result.unwrap(""),
      ))
    [command, ..] -> Error("unknown command or wrong arguments: " <> command)
  }
}

fn split_flags(
  args: List(String),
  positional: List(String),
  flags: dict.Dict(String, String),
) -> Result(#(List(String), dict.Dict(String, String)), String) {
  case args {
    [] -> Ok(#(list.reverse(positional), flags))
    ["--help", ..rest] -> split_flags(rest, ["--help", ..positional], flags)
    ["--" <> name, value, ..rest] ->
      split_flags(rest, positional, dict.insert(flags, name, value))
    ["--" <> name] -> Error("--" <> name <> " needs a value")
    [arg, ..rest] -> split_flags(rest, [arg, ..positional], flags)
  }
}

fn page(flags: dict.Dict(String, String)) -> Result(Page, String) {
  use limit <- result.try(int_flag(flags, "limit", default_limit))
  use offset <- result.try(int_flag(flags, "offset", 0))
  Ok(Page(limit, offset))
}

fn int_flag(
  flags: dict.Dict(String, String),
  name: String,
  default: Int,
) -> Result(Int, String) {
  case dict.get(flags, name) {
    Error(_) -> Ok(default)
    Ok(value) ->
      int.parse(value)
      |> result.replace_error("--" <> name <> " must be a number")
  }
}

fn favorite_kind(kind: String) -> Result(FavoriteKind, String) {
  case kind {
    "tracks" -> Ok(FavoriteTracks)
    "albums" -> Ok(FavoriteAlbums)
    "artists" -> Ok(FavoriteArtists)
    _ -> Error("favorites kind must be tracks, albums or artists")
  }
}
