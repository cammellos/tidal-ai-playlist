import tidal_ai_playlist/internal/playlist_parser
import tidal_ai_playlist/internal/types

pub fn parse_basic_test() {
  let input = "Artist1\tTitle1\nArtist2\tTitle2"
  let tracks = playlist_parser.parse(input)
  assert tracks == [
    types.Track(artist: "Artist1", title: "Title1"),
    types.Track(artist: "Artist2", title: "Title2"),
  ]
}

pub fn parse_with_separator_test() {
  let input = "header\n=======\nArtist1\tTitle1\nArtist2\tTitle2"
  let tracks = playlist_parser.parse(input)
  assert tracks == [
    types.Track(artist: "Artist1", title: "Title1"),
    types.Track(artist: "Artist2", title: "Title2"),
  ]
}

pub fn parse_with_empty_lines_test() {
  let input = "=======\nArtist1\tTitle1\n\nArtist2\tTitle2\n"
  let tracks = playlist_parser.parse(input)
  assert tracks == [
    types.Track(artist: "Artist1", title: "Title1"),
    types.Track(artist: "Artist2", title: "Title2"),
  ]
}

pub fn parse_invalid_lines_test() {
  let input = "=======\nArtist1\tTitle1\nInvalidLine\nArtist2\tTitle2"
  let tracks = playlist_parser.parse(input)
  assert tracks == [
    types.Track(artist: "Artist1", title: "Title1"),
    types.Track(artist: "Artist2", title: "Title2"),
  ]
}
