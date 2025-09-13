import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/int
import gleam/io
import gleam/json
import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http as tidal_http
import tidal_ai_playlist/internal/json as tidal_json

pub type RefreshTokenResponse {
  RefreshTokenResponse(access_token: String, user_id: Int)
}

fn refresh_token_response_decoder() -> decode.Decoder(RefreshTokenResponse) {
  {
    use access_token <- decode.field("access_token", decode.string)
    use user_id <- decode.field("user_id", decode.int)
    decode.success(RefreshTokenResponse(
      access_token: access_token,
      user_id: user_id,
    ))
  }
}

pub fn decode_refresh_token_response(
  body: String,
) -> Result(RefreshTokenResponse, errors.TidalError) {
  case json.parse(from: body, using: refresh_token_response_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) ->
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_json.error_to_string(err),
      ))
  }
}

type TopHit {
  TopHit(id: Int, title: String)
}

pub type SearchTrackResponse {
  SearchTrackResponse(id: Int, title: String)
}

fn value_decoder() -> decode.Decoder(TopHit) {
  {
    use id <- decode.field("id", decode.int)
    use title <- decode.field("title", decode.string)
    decode.success(TopHit(id: id, title: title))
  }
}

fn top_hit_decoder() -> decode.Decoder(TopHit) {
  {
    use top_hit <- decode.field("value", value_decoder())
    decode.success(top_hit)
  }
}

fn search_track_response_decoder() -> decode.Decoder(SearchTrackResponse) {
  {
    use top_hit <- decode.field("topHit", top_hit_decoder())
    decode.success(SearchTrackResponse(id: top_hit.id, title: top_hit.title))
  }
}

pub fn decode_search_track_response(
  body: String,
) -> Result(SearchTrackResponse, errors.TidalError) {
  case json.parse(from: body, using: search_track_response_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) -> {
      io.println(tidal_json.error_to_string(err))
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_json.error_to_string(err),
      ))
    }
  }
}

pub type CreatePlaylistResponse {
  CreatePlaylistResponse(id: String, etag: String)
}

fn create_playlist_response_decoder() -> decode.Decoder(CreatePlaylistResponse) {
  {
    use id <- decode.field("uuid", decode.string)
    decode.success(CreatePlaylistResponse(id: id, etag: ""))
  }
}

pub fn decode_create_playlist_response(
  body: String,
) -> Result(CreatePlaylistResponse, errors.TidalError) {
  case json.parse(from: body, using: create_playlist_response_decoder()) {
    Ok(decoded_response) -> Ok(decoded_response)
    Error(err) -> {
      io.println(tidal_json.error_to_string(err))
      Error(errors.ParseError(
        "Failed to parse json: " <> tidal_json.error_to_string(err),
      ))
    }
  }
}

pub type AddTracksToPlaylistResponse {
  AddTracksToPlaylistResponse(body: String)
}

pub fn decode_add_tracks_to_playlist_response(
  body: String,
) -> Result(AddTracksToPlaylistResponse, errors.TidalError) {
  Ok(AddTracksToPlaylistResponse(body: body))
  //case json.parse(from: body, using: create_playlist_response_decoder()) {
  //  Ok(decoded_response) -> Ok(decoded_response)
  //  Error(err) -> {
  //    io.println(tidal_json.error_to_string(err))
  //    Error(errors.ParseError(
  //      "Failed to parse json: " <> tidal_json.error_to_string(err),
  //    ))
  //  }
  // }
}
