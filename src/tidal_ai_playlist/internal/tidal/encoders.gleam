import gleam/int
import gleam/json

import tidal_ai_playlist/internal/tidal/types

pub fn paged(page: types.Paged(a), encode: fn(a) -> json.Json) -> json.Json {
  json.object([
    #("total", json.int(page.total)),
    #("offset", json.int(page.offset)),
    #("limit", json.int(page.limit)),
    #("items", json.array(page.items, encode)),
  ])
}

pub fn track(track: types.Track) -> json.Json {
  json.object([
    #("id", json.int(track.id)),
    #("title", json.string(track.title)),
    #("version", json.nullable(track.version, json.string)),
    #("artists", json.array(track.artists, json.string)),
    #("album", json.nullable(track.album, json.string)),
    #("duration", json.int(track.duration)),
    #("url", json.string(url("track", track.id))),
  ])
}

pub fn album(album: types.Album) -> json.Json {
  json.object([
    #("id", json.int(album.id)),
    #("title", json.string(album.title)),
    #("artists", json.array(album.artists, json.string)),
    #("release_date", json.nullable(album.release_date, json.string)),
    #("number_of_tracks", json.int(album.number_of_tracks)),
    #("url", json.string(url("album", album.id))),
  ])
}

pub fn artist(artist: types.Artist) -> json.Json {
  json.object([
    #("id", json.int(artist.id)),
    #("name", json.string(artist.name)),
    #("url", json.string(url("artist", artist.id))),
  ])
}

pub fn playlist(playlist: types.PlaylistSummary) -> json.Json {
  json.object([
    #("uuid", json.string(playlist.uuid)),
    #("title", json.string(playlist.title)),
    #("description", json.nullable(playlist.description, json.string)),
    #("number_of_tracks", json.int(playlist.number_of_tracks)),
    #("last_updated", json.string(playlist.last_updated)),
    #("url", json.string(playlist_url(playlist.uuid))),
  ])
}

pub fn favorite(
  favorite: types.Favorite(a),
  encode: fn(a) -> json.Json,
) -> json.Json {
  json.object([
    #("added", json.string(favorite.added)),
    #("item", encode(favorite.item)),
  ])
}

pub fn playlist_url(uuid: String) -> String {
  "https://tidal.com/browse/playlist/" <> uuid
}

fn url(kind: String, id: Int) -> String {
  "https://tidal.com/browse/" <> kind <> "/" <> int.to_string(id)
}
