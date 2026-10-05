import gleam/option

import tidal_ai_playlist/fixtures
import tidal_ai_playlist/internal/tidal/decoders
import tidal_ai_playlist/internal/tidal/types

pub fn decode_search_tracks_response_test() {
  let assert Ok(page) =
    decoders.decode_search_tracks_response(fixtures.search_track_response)
  assert page.total == 6
  let assert [first, ..] = page.items
  assert first
    == types.Track(
      id: 81_930_885,
      title: "Moonlight On Vermont (Live)",
      version: option.None,
      duration: 228,
      artists: ["Captain Beefheart"],
      album: option.Some("My Fathers Place, Roslyn, 78"),
    )
}

pub fn decode_playlists_response_test() {
  assert decoders.decode_playlists_response(fixtures.playlists_response)
    == Ok(types.Paged(
      items: [
        types.PlaylistSummary(
          "pl-1",
          "first",
          option.Some("desc"),
          4,
          "2025-09-15T07:00:44.615+0000",
        ),
        types.PlaylistSummary(
          "pl-2",
          "second",
          option.None,
          0,
          "2025-09-14T07:00:44.615+0000",
        ),
      ],
      total: 22,
      offset: 0,
      limit: 2,
    ))
}

pub fn decode_playlist_items_skips_videos_test() {
  let assert Ok(page) =
    decoders.decode_playlist_items_response(fixtures.playlist_items_response)
  assert page.items
    == [
      types.Track(
        1,
        "Song One",
        option.None,
        386,
        ["Artist One"],
        option.Some("Album One"),
      ),
      types.Track(
        3,
        "Song Three",
        option.Some("Live"),
        200,
        ["Artist One", "Artist Two"],
        option.None,
      ),
    ]
}

pub fn decode_favorite_albums_response_test() {
  let assert Ok(page) =
    decoders.decode_favorite_albums_response(fixtures.favorite_albums_response)
  assert page.items
    == [
      types.Favorite(
        types.Album(345, "2093", ["Yeat"], option.Some("2024-02-16"), 22),
        "2025-01-07T09:38:40.596+0000",
      ),
    ]
}

pub fn decode_favorite_artists_response_test() {
  let assert Ok(page) =
    decoders.decode_favorite_artists_response(
      fixtures.favorite_artists_response,
    )
  assert page.total == 34
  assert page.items
    == [
      types.Favorite(
        types.Artist(48, "Angine de Poitrine"),
        "2026-03-12T11:50:45.889+0000",
      ),
    ]
}
