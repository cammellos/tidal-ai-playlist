pub type Track {
  Track(artist: String, title: String)
}

pub type Playlist {
  Playlist(songs: List(Track), title: String, description: String)
}
