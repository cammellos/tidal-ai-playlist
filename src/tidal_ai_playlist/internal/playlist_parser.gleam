import gleam/list
import gleam/string

import tidal_ai_playlist/internal/types

pub fn parse(playlist: String) -> List(types.Track) {
  let separator = "======="

  let parts = string.split(playlist, separator)
  let inner = case parts {
    [_before, inner, ..] -> string.trim(inner)
    [only] -> string.trim(only)
    _ -> playlist
  }

  string.split(inner, "\n")
  |> list.filter(fn(line) {
    let trimmed = string.trim(line)
    trimmed != "" && trimmed != separator
  })
  |> list.map(fn(line) {
    let fields = string.split(line, "\t")
    case fields {
      [artist, title] ->
        types.Track(artist: string.trim(artist), title: string.trim(title))
      _ -> {
        types.Track(artist: "", title: "")
      }
    }
  })
  |> list.filter(fn(song) { song.artist != "" && song.title != "" })
}
