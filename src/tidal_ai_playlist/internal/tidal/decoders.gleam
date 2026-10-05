import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/json as tidal_ai_playlist_json
import tidal_ai_playlist/internal/tidal/types

pub fn decode_device_authorization_response(
  body: String,
) -> Result(types.DeviceAuthorizationResponse, errors.TidalAIPlaylistError) {
  decode_json(body, device_authorization_decoder())
}

pub fn decode_oauth_token_response(
  body: String,
) -> Result(types.OauthToken, errors.TidalAIPlaylistError) {
  decode_json(body, oauth_token_decoder())
}

pub fn decode_refresh_token_response(
  body: String,
) -> Result(types.RefreshTokenResponse, errors.TidalAIPlaylistError) {
  decode_json(body, refresh_token_response_decoder())
}

pub fn decode_create_playlist_response(
  body: String,
) -> Result(types.CreatePlaylistResponse, errors.TidalAIPlaylistError) {
  decode_json(body, create_playlist_response_decoder())
}

pub fn decode_search_track_response(
  body: String,
) -> Result(types.SearchTrackResponse, errors.TidalAIPlaylistError) {
  decode_json(body, search_track_response_decoder())
}

pub fn decode_add_tracks_to_playlist(
  text: String,
) -> Result(types.AddTracksToPlaylistResponse, errors.TidalAIPlaylistError) {
  decode_json(text, add_tracks_to_playlist_decoder())
}

pub fn decode_config(
  text: String,
) -> Result(types.Config, errors.TidalAIPlaylistError) {
  decode_json(text, config_decoder())
}

pub fn decode_search_tracks_response(
  body: String,
) -> Result(types.Paged(types.Track), errors.TidalAIPlaylistError) {
  decode_json(body, decode.at(["tracks"], paged_decoder(track_decoder())))
}

pub fn decode_playlists_response(
  body: String,
) -> Result(types.Paged(types.PlaylistSummary), errors.TidalAIPlaylistError) {
  decode_json(body, paged_decoder(playlist_summary_decoder()))
}

/// Playlist items can be videos too; only tracks are kept.
pub fn decode_playlist_items_response(
  body: String,
) -> Result(types.Paged(types.Track), errors.TidalAIPlaylistError) {
  use paged <- result.map(decode_json(
    body,
    paged_decoder(playlist_item_decoder()),
  ))
  types.Paged(..paged, items: option.values(paged.items))
}

pub fn decode_favorite_tracks_response(
  body: String,
) -> Result(
  types.Paged(types.Favorite(types.Track)),
  errors.TidalAIPlaylistError,
) {
  decode_json(body, paged_decoder(favorite_decoder(track_decoder())))
}

pub fn decode_favorite_albums_response(
  body: String,
) -> Result(
  types.Paged(types.Favorite(types.Album)),
  errors.TidalAIPlaylistError,
) {
  decode_json(body, paged_decoder(favorite_decoder(album_decoder())))
}

pub fn decode_favorite_artists_response(
  body: String,
) -> Result(
  types.Paged(types.Favorite(types.Artist)),
  errors.TidalAIPlaylistError,
) {
  decode_json(body, paged_decoder(favorite_decoder(artist_decoder())))
}

fn oauth_token_decoder() -> decode.Decoder(types.OauthToken) {
  {
    use access_token <- decode.field("access_token", decode.string)
    use refresh_token <- decode.field("refresh_token", decode.string)
    use expires_in <- decode.field("expires_in", decode.int)
    use user_id <- decode.field("user_id", decode.int)
    decode.success(types.OauthToken(
      access_token,
      refresh_token,
      expires_in,
      user_id,
    ))
  }
}

fn device_authorization_decoder() -> decode.Decoder(
  types.DeviceAuthorizationResponse,
) {
  {
    use device_code <- decode.field("deviceCode", decode.string)
    use user_code <- decode.field("userCode", decode.string)
    use verification_uri <- decode.field("verificationUri", decode.string)
    use verification_uri_complete <- decode.field(
      "verificationUriComplete",
      decode.string,
    )
    use expires_in <- decode.field("expiresIn", decode.int)
    use interval <- decode.field("interval", decode.int)

    decode.success(types.DeviceAuthorizationResponse(
      device_code: device_code,
      user_code: user_code,
      verification_uri: verification_uri,
      verification_uri_complete: verification_uri_complete,
      expires_in: expires_in,
      interval: interval,
    ))
  }
}

fn refresh_token_response_decoder() -> decode.Decoder(
  types.RefreshTokenResponse,
) {
  {
    use access_token <- decode.field("access_token", decode.string)
    use user_id <- decode.field("user_id", decode.int)
    decode.success(types.RefreshTokenResponse(
      access_token: access_token,
      user_id: user_id,
    ))
  }
}

fn create_playlist_response_decoder() -> decode.Decoder(
  types.CreatePlaylistResponse,
) {
  {
    use id <- decode.field("uuid", decode.string)
    decode.success(types.CreatePlaylistResponse(id: id, etag: ""))
  }
}

fn search_track_response_decoder() -> decode.Decoder(types.SearchTrackResponse) {
  {
    use top_hit <- decode.field("topHit", top_hit_decoder())
    decode.success(types.SearchTrackResponse(
      id: top_hit.id,
      title: top_hit.title,
    ))
  }
}

fn top_hit_decoder() -> decode.Decoder(types.TopHit) {
  {
    use top_hit <- decode.field("value", value_decoder())
    decode.success(top_hit)
  }
}

fn value_decoder() -> decode.Decoder(types.TopHit) {
  {
    use id <- decode.field("id", decode.int)
    use title <- decode.field("title", decode.string)
    decode.success(types.TopHit(id: id, title: title))
  }
}

fn add_tracks_to_playlist_decoder() -> decode.Decoder(
  types.AddTracksToPlaylistResponse,
) {
  {
    use last_updated <- decode.field("lastUpdated", decode.int)
    use added_item_ids <- decode.field("addedItemIds", decode.list(decode.int))
    decode.success(types.AddTracksToPlaylistResponse(
      last_updated,
      added_item_ids,
    ))
  }
}

fn config_decoder() -> decode.Decoder(types.Config) {
  {
    use client_id <- decode.field("client_id", decode.string)
    use client_secret <- decode.field("client_secret", decode.string)
    use refresh_token <- decode.field("refresh_token", decode.string)
    use user_id <- decode.field("user_id", decode.int)
    decode.success(types.Config(
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: option.Some(refresh_token),
      access_token: option.None,
      user_id: option.Some(user_id),
      http_client: option.None,
      output_fn: option.None,
      session_id: "",
    ))
  }
}

fn paged_decoder(item: decode.Decoder(a)) -> decode.Decoder(types.Paged(a)) {
  use items <- decode.field("items", decode.list(item))
  use total <- decode.optional_field(
    "totalNumberOfItems",
    list.length(items),
    decode.int,
  )
  use offset <- decode.optional_field("offset", 0, decode.int)
  use limit <- decode.optional_field("limit", list.length(items), decode.int)
  decode.success(types.Paged(items:, total:, offset:, limit:))
}

fn track_decoder() -> decode.Decoder(types.Track) {
  use id <- decode.field("id", decode.int)
  use title <- decode.field("title", decode.string)
  use version <- decode.optional_field(
    "version",
    option.None,
    decode.optional(decode.string),
  )
  use duration <- decode.optional_field("duration", 0, decode.int)
  use artists <- decode.optional_field(
    "artists",
    [],
    decode.list(decode.at(["name"], decode.string)),
  )
  use album <- decode.optional_field(
    "album",
    option.None,
    decode.optional(decode.at(["title"], decode.string)),
  )
  decode.success(types.Track(id:, title:, version:, duration:, artists:, album:))
}

fn album_decoder() -> decode.Decoder(types.Album) {
  use id <- decode.field("id", decode.int)
  use title <- decode.field("title", decode.string)
  use artists <- decode.optional_field(
    "artists",
    [],
    decode.list(decode.at(["name"], decode.string)),
  )
  use release_date <- decode.optional_field(
    "releaseDate",
    option.None,
    decode.optional(decode.string),
  )
  use number_of_tracks <- decode.optional_field("numberOfTracks", 0, decode.int)
  decode.success(types.Album(
    id:,
    title:,
    artists:,
    release_date:,
    number_of_tracks:,
  ))
}

fn artist_decoder() -> decode.Decoder(types.Artist) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  decode.success(types.Artist(id:, name:))
}

fn playlist_summary_decoder() -> decode.Decoder(types.PlaylistSummary) {
  use uuid <- decode.field("uuid", decode.string)
  use title <- decode.field("title", decode.string)
  use description <- decode.optional_field(
    "description",
    option.None,
    decode.optional(decode.string),
  )
  use number_of_tracks <- decode.optional_field("numberOfTracks", 0, decode.int)
  use last_updated <- decode.optional_field("lastUpdated", "", decode.string)
  decode.success(types.PlaylistSummary(
    uuid:,
    title:,
    description:,
    number_of_tracks:,
    last_updated:,
  ))
}

fn playlist_item_decoder() -> decode.Decoder(option.Option(types.Track)) {
  use item_type <- decode.field("type", decode.string)
  case item_type {
    "track" -> {
      use track <- decode.field("item", track_decoder())
      decode.success(option.Some(track))
    }
    _ -> decode.success(option.None)
  }
}

fn favorite_decoder(
  item: decode.Decoder(a),
) -> decode.Decoder(types.Favorite(a)) {
  use item <- decode.field("item", item)
  use added <- decode.optional_field("created", "", decode.string)
  decode.success(types.Favorite(item:, added:))
}

fn decode_json(
  text: String,
  decoder: decode.Decoder(a),
) -> Result(a, errors.TidalAIPlaylistError) {
  case json.parse(from: text, using: decoder) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_ai_playlist_json.error_to_string(err),
      ))
  }
}
