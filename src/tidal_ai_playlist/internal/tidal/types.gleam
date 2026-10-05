import gleam/option
import tidal_ai_playlist/internal/http

pub type DeviceAuthorizationResponse {
  DeviceAuthorizationResponse(
    device_code: String,
    user_code: String,
    verification_uri: String,
    verification_uri_complete: String,
    expires_in: Int,
    interval: Int,
  )
}

pub type OauthToken {
  OauthToken(
    access_token: String,
    refresh_token: String,
    expires_in: Int,
    user_id: Int,
  )
}

pub type RefreshTokenResponse {
  RefreshTokenResponse(access_token: String, user_id: Int)
}

pub type CreatePlaylistResponse {
  CreatePlaylistResponse(id: String, etag: String)
}

pub type SearchTrackResponse {
  SearchTrackResponse(id: Int, title: String)
}

pub type TopHit {
  TopHit(id: Int, title: String)
}

pub type AddTracksToPlaylistResponse {
  AddTracksToPlaylistResponse(last_updated: Int, added_item_ids: List(Int))
}

pub type Config {
  Config(
    client_id: String,
    client_secret: String,
    refresh_token: option.Option(String),
    user_id: option.Option(Int),
    access_token: option.Option(String),
    session_id: String,
    http_client: option.Option(http.Client),
    output_fn: option.Option(fn(String) -> Nil),
  )
}

pub type Track {
  Track(
    id: Int,
    title: String,
    version: option.Option(String),
    duration: Int,
    artists: List(String),
    album: option.Option(String),
  )
}

pub type Album {
  Album(
    id: Int,
    title: String,
    artists: List(String),
    release_date: option.Option(String),
    number_of_tracks: Int,
  )
}

pub type Artist {
  Artist(id: Int, name: String)
}

pub type PlaylistSummary {
  PlaylistSummary(
    uuid: String,
    title: String,
    description: option.Option(String),
    number_of_tracks: Int,
    last_updated: String,
  )
}

pub type Favorite(a) {
  Favorite(item: a, added: String)
}

pub type Paged(a) {
  Paged(items: List(a), total: Int, offset: Int, limit: Int)
}
