import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/int
import gleam/io
import gleam/option
import gleam/otp/actor
import gleam/result

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/http
import tidal_ai_playlist/internal/tidal/api
import tidal_ai_playlist/internal/tidal/config
import tidal_ai_playlist/internal/tidal/types

pub fn login_error_test() {
  let assert Ok(actor) =
    actor.new(0)
    |> actor.on_message(handle_message)
    |> actor.start

  let client = fn(req: request.Request(String)) -> Result(
    http.HttpResponse,
    errors.TidalAPIError,
  ) {
    case req.path {
      "/v1/oauth2/device_authorization" ->
        Ok(http.HttpResponse(
          status: 200,
          body: device_authorization_response,
          etag: "100",
        ))
      "/v1/oauth2/token" -> {
        actor.send(actor.data, Hit)
        case actor.call(actor.data, waiting: 10, sending: Get) {
          2 ->
            Ok(http.HttpResponse(
              status: 200,
              body: device_authorization_success_response,
              etag: "100",
            ))
          _ ->
            Ok(http.HttpResponse(
              status: 400,
              body: device_authorization_pending_response,
              etag: "100",
            ))
        }
      }
      _ -> Error(errors.HttpError("failed"))
    }
  }

  let config = dummy_config() |> config.add_http_client(client)
  assert Ok(types.OauthToken("access-token", "refresh-token", 43_200, 1))
    == api.login(config)
}

pub fn refresh_token_missing_test() {
  let result = api.refresh_token(dummy_config())
  assert result == Error(errors.TidalRefreshTokenMissing)
}

pub fn refresh_token_test() {
  let client = build_client(refresh_token_response)
  let config =
    dummy_config()
    |> config.add_refresh_token("refresh-token")
    |> config.add_http_client(client)

  assert Ok(types.RefreshTokenResponse("access-token", 1))
    == api.refresh_token(config)
}

pub fn create_playlist_missing_token_test() {
  let result = api.create_playlist(dummy_config(), "title", "desc")
  assert result == Error(errors.TidalAccessTokenMissing)
}

pub fn create_playlist_test() {
  let client = build_client(create_playlist_response)
  let config = dummy_config_with_tokens() |> config.add_http_client(client)
  assert Ok(types.CreatePlaylistResponse(
      "3758b8a5-dcbd-46f8-8f36-6869b46b7e5b",
      "100",
    ))
    == api.create_playlist(config, "title", "desc")
}

pub fn search_track_missing_token_test() {
  let result =
    api.search_track(
      dummy_config(),
      "captain beefheart",
      "moonlight on vermont",
    )
  assert result == Error(errors.TidalAccessTokenMissing)
}

pub fn search_track_test() {
  let client = build_client(search_track_response)
  let config = dummy_config_with_tokens() |> config.add_http_client(client)

  assert Ok(types.SearchTrackResponse(81_930_885, "Moonlight On Vermont (Live)"))
    == api.search_track(config, "captain beefheart", "moonlight on vermontn")
}

pub fn add_tracks_to_playlist_missing_token_test() {
  let result =
    api.add_tracks_to_playlist(dummy_config(), "playlist", [1, 2], "etag")
  assert result == Error(errors.TidalAccessTokenMissing)
}

pub fn add_tracks_to_playlist_test() {
  let client = build_client(add_tracks_to_playlist_response)
  let config =
    dummy_config()
    |> config.add_access_token("token")
    |> config.add_user_id(1)
    |> config.add_http_client(client)

  assert Ok(types.AddTracksToPlaylistResponse(1, [1, 2]))
    == api.add_tracks_to_playlist(config, "playlist", [1, 2], "etag")
}

fn dummy_config() -> types.Config {
  config.new("test", "test")
}

fn dummy_config_with_tokens() -> types.Config {
  dummy_config() |> config.add_access_token("token") |> config.add_user_id(1)
}

fn build_client(data) -> http.Client {
  fn(_req) { Ok(http.HttpResponse(status: 200, body: data, etag: "100")) }
}

const refresh_token_response = "{\"scope\":\"w_sub w_usr r_usr\",\"user\":{\"userId\":1,\"email\":\"test@gmail.com\",\"countryCode\":\"GB\",\"fullName\":null,\"firstName\":null,\"lastName\":null,\"nickname\":null,\"username\":\"test@gmail.com\",\"address\":null,\"city\":null,\"postalcode\":null,\"usState\":null,\"phoneNumber\":null,\"birthday\":528854400000,\"channelId\":2,\"parentId\":0,\"acceptedEULA\":true,\"created\":1726936891344,\"updated\":1732788161659,\"facebookUid\":0,\"appleUid\":null,\"googleUid\":\"1\",\"accountLinkCreated\":false,\"emailVerified\":false,\"newUser\":false},\"clientName\":\"Android Automotive\",\"token_type\":\"Bearer\",\"access_token\":\"access-token\",\"expires_in\":43200,\"user_id\":1}"

const create_playlist_response = "{\"uuid\":\"3758b8a5-dcbd-46f8-8f36-6869b46b7e5b\",\"title\":\"title\",\"numberOfTracks\":0,\"numberOfVideos\":0,\"creator\":{\"id\":1},\"description\":\"desc\",\"duration\":0,\"lastUpdated\":\"2025-09-13T17:24:05.504+0000\",\"created\":\"2025-09-13T17:24:05.504+0000\",\"type\":\"USER\",\"publicPlaylist\":false,\"url\":\"http://www.tidal.com/playlist/3758b8a5-dcbd-46f8-8f36-6869b46b7e5b\",\"image\":\"e59903d7-94a7-454c-8a78-6a6586967dda\",\"popularity\":0,\"squareImage\":\"e9448a9a-3ade-4f79-93d2-12e6d8d4b2eb\",\"customImageUrl\":null,\"promotedArtists\":[],\"lastItemAddedAt\":null}"

const search_track_response = "{\"artists\":{\"limit\":50,\"offset\":0,\"totalNumberOfItems\":0,\"items\":[]},\"albums\":{\"limit\":50,\"offset\":0,\"totalNumberOfItems\":0,\"items\":[]},\"playlists\":{\"limit\":50,\"offset\":0,\"totalNumberOfItems\":0,\"items\":[]},\"tracks\":{\"limit\":50,\"offset\":0,\"totalNumberOfItems\":6,\"items\":[{\"id\":81930885,\"title\":\"Moonlight On Vermont (Live)\",\"duration\":228,\"replayGain\":-8.39,\"peak\":0.923949,\"allowStreaming\":true,\"streamReady\":true,\"payToStream\":false,\"adSupportedStreamReady\":true,\"djReady\":true,\"stemReady\":false,\"streamStartDate\":\"2017-11-29T00:00:00.000+0000\",\"premiumStreamingOnly\":false,\"trackNumber\":12,\"volumeNumber\":1,\"version\":null,\"popularity\":14,\"copyright\":\"Keyhole\",\"bpm\":null,\"url\":\"http://www.tidal.com/track/81930885\",\"isrc\":\"GBSMU4458890\",\"editable\":false,\"explicit\":false,\"audioQuality\":\"LOSSLESS\",\"audioModes\":[\"STEREO\"],\"mediaMetadata\":{\"tags\":[\"LOSSLESS\"]},\"upload\":false,\"accessType\":null,\"spotlighted\":false,\"artists\":[{\"id\":9534,\"name\":\"Captain Beefheart\",\"handle\":null,\"type\":\"MAIN\",\"picture\":\"3e83f571-bd01-47c7-920f-d2d556fde98e\"}],\"album\":{\"id\":81930873,\"title\":\"My Fathers Place, Roslyn, 78\",\"cover\":\"a95cad18-053a-459d-82ee-f5052c710d81\",\"vibrantColor\":\"#dad94d\",\"videoCover\":null,\"releaseDate\":\"2017-11-17\"},\"mixes\":{\"TRACK_MIX\":\"001e4668906255bffd2996646c75b9\"}},{\"id\":63435274,\"title\":\"Moonlight On Vermont\",\"duration\":235,\"replayGain\":-5.1,\"peak\":0.960266,\"allowStreaming\":true,\"streamReady\":true,\"payToStream\":false,\"adSupportedStreamReady\":true,\"djReady\":true,\"stemReady\":false,\"streamStartDate\":\"2016-08-26T00:00:00.000+0000\",\"premiumStreamingOnly\":false,\"trackNumber\":1,\"volumeNumber\":1,\"version\":\"Live At Knebworth Park Saturday 5th July\",\"popularity\":7,\"copyright\":\"Ozit\",\"bpm\":null,\"url\":\"http://www.tidal.com/track/63435274\",\"isrc\":\"GBHLW1602259\",\"editable\":false,\"explicit\":false,\"audioQuality\":\"LOSSLESS\",\"audioModes\":[\"STEREO\"],\"mediaMetadata\":{\"tags\":[\"LOSSLESS\"]},\"upload\":false,\"accessType\":null,\"spotlighted\":false,\"artists\":[{\"id\":9534,\"name\":\"Captain Beefheart\",\"handle\":null,\"type\":\"MAIN\",\"picture\":\"3e83f571-bd01-47c7-920f-d2d556fde98e\"}],\"album\":{\"id\":63435273,\"title\":\"Live At Knebworth Park Saturday 5th July (Live)\",\"cover\":\"3398d942-dcd6-4e40-a417-a4893cdaf6ad\",\"vibrantColor\":\"#75bacd\",\"videoCover\":null,\"releaseDate\":\"2016-08-26\"},\"mixes\":{\"TRACK_MIX\":\"001be7229def6def335b4c60bb016e\"}},{\"id\":53865003,\"title\":\"Moonlight On Vermont\",\"duration\":237,\"replayGain\":-9.46,\"peak\":0.949981,\"allowStreaming\":true,\"streamReady\":true,\"payToStream\":false,\"adSupportedStreamReady\":true,\"djReady\":true,\"stemReady\":false,\"streamStartDate\":\"2015-11-13T00:00:00.000+0000\",\"premiumStreamingOnly\":false,\"trackNumber\":20,\"volumeNumber\":1,\"version\":\"Live\",\"popularity\":7,\"copyright\":\"Ozit\",\"bpm\":null,\"url\":\"http://www.tidal.com/track/53865003\",\"isrc\":\"GBRHE0810030\",\"editable\":false,\"explicit\":false,\"audioQuality\":\"LOSSLESS\",\"audioModes\":[\"STEREO\"],\"mediaMetadata\":{\"tags\":[\"LOSSLESS\"]},\"upload\":false,\"accessType\":null,\"spotlighted\":false,\"artists\":[{\"id\":9534,\"name\":\"Captain Beefheart\",\"handle\":null,\"type\":\"MAIN\",\"picture\":\"e5c25c9f-5cc8-4708-b065-c21443d8c90e\"}],\"album\":{\"id\":53864983,\"title\":\"Live in GB 1970 - 1980\",\"cover\":\"a592ab79-578d-4a64-8d55-9f4684afed06\",\"vibrantColor\":\"#e5d09e\",\"videoCover\":null,\"releaseDate\":\"2008-09-01\"},\"mixes\":{\"TRACK_MIX\":\"0016c35fc1d70b620a38c9980e84f3\"}},{\"id\":5395502,\"title\":\"Moonlight on Vermont (Live at My Fathers Place 1978)\",\"duration\":233,\"replayGain\":-7.79,\"peak\":0.937775,\"allowStreaming\":true,\"streamReady\":true,\"payToStream\":false,\"adSupportedStreamReady\":true,\"djReady\":true,\"stemReady\":false,\"streamStartDate\":\"2016-11-23T00:00:00.000+0000\",\"premiumStreamingOnly\":false,\"trackNumber\":11,\"volumeNumber\":1,\"version\":null,\"popularity\":4,\"copyright\":\"℗ 1978 Warner Records Inc.\",\"bpm\":null,\"url\":\"http://www.tidal.com/track/5395502\",\"isrc\":\"USWB10302777\",\"editable\":false,\"explicit\":false,\"audioQuality\":\"LOSSLESS\",\"audioModes\":[\"STEREO\"],\"mediaMetadata\":{\"tags\":[\"LOSSLESS\"]},\"upload\":false,\"accessType\":null,\"spotlighted\":false,\"artists\":[{\"id\":9534,\"name\":\"Captain Beefheart\",\"handle\":null,\"type\":\"MAIN\",\"picture\":\"3e83f571-bd01-47c7-920f-d2d556fde98e\"}],\"album\":{\"id\":5395491,\"title\":\"Im Going To Do What I Wanna Do: Live At My Fathers Place 1978\",\"cover\":\"2a8f39ac-71e1-4ba3-97b3-e34ca2362a9b\",\"vibrantColor\":\"#f6f6e4\",\"videoCover\":null,\"releaseDate\":\"2000-09-18\"},\"mixes\":{\"TRACK_MIX\":\"001ba3004f1418f278e01dc85a89ea\"}},{\"id\":53864010,\"title\":\"Moonlight On Vermont\",\"duration\":231,\"replayGain\":-18.44,\"peak\":1.0,\"allowStreaming\":true,\"streamReady\":true,\"payToStream\":false,\"adSupportedStreamReady\":true,\"djReady\":true,\"stemReady\":false,\"streamStartDate\":\"2015-11-13T00:00:00.000+0000\",\"premiumStreamingOnly\":false,\"trackNumber\":6,\"volumeNumber\":1,\"version\":\"Live\",\"popularity\":0,\"copyright\":\"Ozit\",\"bpm\":null,\"url\":\"http://www.tidal.com/track/53864010\",\"isrc\":\"GBRHE1200013\",\"editable\":false,\"explicit\":false,\"audioQuality\":\"LOSSLESS\",\"audioModes\":[\"STEREO\"],\"mediaMetadata\":{\"tags\":[\"LOSSLESS\"]},\"upload\":false,\"accessType\":null,\"spotlighted\":false,\"artists\":[{\"id\":9534,\"name\":\"Captain Beefheart\",\"handle\":null,\"type\":\"MAIN\",\"picture\":\"3e83f571-bd01-47c7-920f-d2d556fde98e\"}],\"album\":{\"id\":53864004,\"title\":\"The Nan Trues Hole Tapes Volume 3 (Live)\",\"cover\":\"16f398e7-2a12-4810-bbd5-2bfb0162fa87\",\"vibrantColor\":\"#e9d09a\",\"videoCover\":null,\"releaseDate\":\"2012-01-31\"},\"mixes\":{\"TRACK_MIX\":\"001575ba5e7d482cea628f9425d344\"}},{\"id\":429319659,\"title\":\"Moonlight on Vermont (Live From Le Nouvel Hippodrome, Paris 19/11/1977)\",\"duration\":231,\"replayGain\":-6.52,\"peak\":0.999969,\"allowStreaming\":true,\"streamReady\":true,\"payToStream\":false,\"adSupportedStreamReady\":true,\"djReady\":true,\"stemReady\":false,\"streamStartDate\":\"2014-05-21T00:00:00.000+0000\",\"premiumStreamingOnly\":false,\"trackNumber\":20,\"volumeNumber\":1,\"version\":null,\"popularity\":0,\"copyright\":\"2014 Gonzo Multimedia\",\"bpm\":null,\"url\":\"http://www.tidal.com/track/429319659\",\"isrc\":\"GB9TT1307319\",\"editable\":false,\"explicit\":false,\"audioQuality\":\"LOSSLESS\",\"audioModes\":[\"STEREO\"],\"mediaMetadata\":{\"tags\":[\"LOSSLESS\"]},\"upload\":false,\"accessType\":null,\"spotlighted\":false,\"artists\":[{\"id\":9534,\"name\":\"Captain Beefheart\",\"handle\":null,\"type\":\"MAIN\",\"picture\":\"3e83f571-bd01-47c7-920f-d2d556fde98e\"}],\"album\":{\"id\":429319637,\"title\":\"Somewhere Over Paris (Live From Le Nouvel Hippodrome, Paris 19/11/1977)\",\"cover\":\"c3d7dfb5-f05c-48ec-8052-ec929645e9cb\",\"vibrantColor\":\"#8b3e34\",\"videoCover\":null,\"releaseDate\":\"2014-12-02\"},\"mixes\":{\"TRACK_MIX\":\"00178a041b825eed59814e39399c77\"}}]},\"videos\":{\"limit\":50,\"offset\":0,\"totalNumberOfItems\":0,\"items\":[]},\"topHit\":{\"value\":{\"id\":81930885,\"title\":\"Moonlight On Vermont (Live)\",\"duration\":228,\"replayGain\":-8.39,\"peak\":0.923949,\"allowStreaming\":true,\"streamReady\":true,\"payToStream\":false,\"adSupportedStreamReady\":true,\"djReady\":true,\"stemReady\":false,\"streamStartDate\":\"2017-11-29T00:00:00.000+0000\",\"premiumStreamingOnly\":false,\"trackNumber\":12,\"volumeNumber\":1,\"version\":null,\"popularity\":14,\"copyright\":\"Keyhole\",\"bpm\":null,\"url\":\"http://www.tidal.com/track/81930885\",\"isrc\":\"GBSMU4458890\",\"editable\":false,\"explicit\":false,\"audioQuality\":\"LOSSLESS\",\"audioModes\":[\"STEREO\"],\"mediaMetadata\":{\"tags\":[\"LOSSLESS\"]},\"upload\":false,\"accessType\":null,\"spotlighted\":false,\"artists\":[{\"id\":9534,\"name\":\"Captain Beefheart\",\"handle\":null,\"type\":\"MAIN\",\"picture\":\"3e83f571-bd01-47c7-920f-d2d556fde98e\"}],\"album\":{\"id\":81930873,\"title\":\"My Fathers Place, Roslyn, 78\",\"cover\":\"a95cad18-053a-459d-82ee-f5052c710d81\",\"vibrantColor\":\"#dad94d\",\"videoCover\":null,\"releaseDate\":\"2017-11-17\"},\"mixes\":{\"TRACK_MIX\":\"001e4668906255bffd2996646c75b9\"}},\"type\":\"TRACKS\"}}"

const add_tracks_to_playlist_response = "{\"lastUpdated\":1,\"addedItemIds\":[1, 2]}"

const device_authorization_response = "{\"deviceCode\":\"85cf24ed-3aae-4821-a7a2-6f7668c29b0e\",\"userCode\":\"WQTUF\",\"verificationUri\":\"link.tidal.com\",\"verificationUriComplete\":\"link.tidal.com/WQTUF\",\"expiresIn\":300,\"interval\":2}"

const device_authorization_pending_response = "{\"status\":400,\"error\":\"authorization_pending\",\"sub_status\":1002,\"error_description\":\"Device Authorization code is not authorized yet\"}"

const device_authorization_success_response = "{\"scope\":\"w_usr w_sub r_usr\",\"user\":{\"userId\":1,\"email\":\"test@gmail.com\",\"countryCode\":\"GB\",\"fullName\":null,\"firstName\":null,\"lastName\":null,\"nickname\":null,\"username\":\"test@gmail.com\",\"address\":null,\"city\":null,\"postalcode\":null,\"usState\":null,\"phoneNumber\":null,\"birthday\":528854400000,\"channelId\":323,\"parentId\":0,\"acceptedEULA\":true,\"created\":1726936891344,\"updated\":1732788161659,\"facebookUid\":0,\"appleUid\":null,\"googleUid\":\"1\",\"accountLinkCreated\":false,\"emailVerified\":false,\"newUser\":false},\"clientName\":\"Android Automotive\",\"token_type\":\"Bearer\",\"access_token\":\"access-token\",\"refresh_token\":\"refresh-token\",\"expires_in\":43200,\"user_id\":1}"

pub fn handle_message(state: Int, message: Message) -> actor.Next(Int, Message) {
  case message {
    Hit -> {
      let state = state + 1
      actor.continue(state)
    }
    Get(reply) -> {
      actor.send(reply, state)
      actor.continue(state)
    }
  }
}

pub type Message {
  Hit
  Get(Subject(Int))
}
