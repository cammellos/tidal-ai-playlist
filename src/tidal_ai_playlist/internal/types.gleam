import tidal_ai_playlist/internal/http

pub type Track {
  Track(artist: String, title: String)
}

pub type Playlist {
  Playlist(songs: List(Track), title: String, description: String)
}

pub type Dependencies {
  Dependencies(
    get_env_fn: fn(String) -> Result(String, Nil),
    output_fn: fn(String) -> Nil,
    http_client: http.Client,
    input_fn: fn(String) -> Result(String, Nil),
  )
}
