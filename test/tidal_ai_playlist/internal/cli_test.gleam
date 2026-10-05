import gleam/option

import tidal_ai_playlist/internal/cli

pub fn no_arguments_is_interactive_test() {
  assert cli.parse([]) == Ok(cli.Interactive)
}

pub fn search_joins_words_test() {
  assert cli.parse(["search", "angine", "de", "poitrine", "--limit", "3"])
    == Ok(cli.Search("angine de poitrine", 3))
}

pub fn search_default_limit_test() {
  assert cli.parse(["search", "x"]) == Ok(cli.Search("x", 10))
}

pub fn favorites_defaults_to_tracks_test() {
  assert cli.parse(["favorites"])
    == Ok(cli.Favorites(cli.FavoriteTracks, cli.Page(50, 0)))
}

pub fn favorites_kind_and_page_test() {
  assert cli.parse(["favorites", "artists", "--offset", "10", "--limit", "5"])
    == Ok(cli.Favorites(cli.FavoriteArtists, cli.Page(5, 10)))
}

pub fn favorites_unknown_kind_test() {
  let assert Error(_) = cli.parse(["favorites", "videos"])
}

pub fn add_parses_track_ids_test() {
  assert cli.parse(["add", "pl-1", "1", "2"])
    == Ok(cli.AddTracks("pl-1", [1, 2]))
}

pub fn add_rejects_bad_track_id_test() {
  assert cli.parse(["add", "pl-1", "nope"]) == Error("not a track id: nope")
}

pub fn generate_with_flags_test() {
  assert cli.parse(["generate", "sad", "jazz", "--title", "T"])
    == Ok(cli.Generate("sad jazz", option.Some("T"), ""))
}

pub fn login_needs_output_test() {
  let assert Error(_) = cli.parse(["login"])
  assert cli.parse(["login", "--output", "f.json"]) == Ok(cli.Login("f.json"))
}

pub fn flag_without_value_test() {
  assert cli.parse(["search", "x", "--limit"]) == Error("--limit needs a value")
}
