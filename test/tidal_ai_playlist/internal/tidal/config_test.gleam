import gleam/option

import simplifile
import youid/uuid

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/tidal/config

pub fn new_test() {
  let client_id = "id"
  let client_secret = "secret"
  let conf = config.new(client_id, client_secret)
  assert conf.client_id == client_id
  assert conf.client_secret == client_secret
  assert conf.refresh_token == option.None
  assert conf.access_token == option.None
  assert conf.user_id == option.None
}

pub fn add_refresh_token_test() {
  let conf = config.new("id", "secret")
  let updated = config.add_refresh_token(conf, "refresh")
  assert updated.refresh_token == option.Some("refresh")
}

pub fn add_access_token_test() {
  let conf = config.new("id", "secret")
  let updated = config.add_access_token(conf, "access")
  assert updated.access_token == option.Some("access")
}

pub fn add_user_id_test() {
  let conf = config.new("id", "secret")
  let updated = config.add_user_id(conf, 42)
  assert updated.user_id == option.Some(42)
}

pub fn from_file_missing_test() {
  assert Error(errors.TidalReadingConfigError)
    == config.from_file("nonexisteng.json")
}

pub fn from_file_valid_test() {
  let filepath = "/tmp/tidal_ai_playlist_test_" <> uuid.v4_string() <> ".json"
  let valid_json =
    "
    {
      \"client_id\": \"some_client_id\",
      \"client_secret\": \"some_client_secret\",
      \"refresh_token\": \"some_refresh_token\"
    }
  "
  let assert Ok(_) = simplifile.write(valid_json, to: filepath)
  let assert Ok(actual_config) = config.from_file(filepath)

  assert actual_config.client_id == "some_client_id"
  assert actual_config.client_secret == "some_client_secret"
  assert actual_config.refresh_token == option.Some("some_refresh_token")
}

pub fn from_file_missing_client_id_test() {
  let filepath = "/tmp/tidal_ai_playlist_test_" <> uuid.v4_string() <> ".json"
  let valid_json =
    "
    {
      \"client_secret\": \"some_client_secret\",
      \"refresh_token\": \"some_refresh_token\"
    }
  "
  let assert Ok(_) = simplifile.write(valid_json, to: filepath)
  let assert Error(errors.ParseError(_)) = config.from_file(filepath)
}

pub fn from_file_missing_client_secret_test() {
  let filepath = "/tmp/tidal_ai_playlist_test_" <> uuid.v4_string() <> ".json"
  let valid_json =
    "
    {
      \"client_id\": \"some_client_id\",
      \"refresh_token\": \"some_refresh_token\"
    }
  "
  let assert Ok(_) = simplifile.write(valid_json, to: filepath)
  let assert Error(errors.ParseError(_)) = config.from_file(filepath)
}

pub fn from_file_missing_refresh_token_test() {
  let filepath = "/tmp/tidal_ai_playlist_test_" <> uuid.v4_string() <> ".json"
  let valid_json =
    "
    {
      \"client_id\": \"some_client_id\",
      \"client_id\": \"some_client_id\"
    }
  "
  let assert Ok(_) = simplifile.write(valid_json, to: filepath)
  let assert Error(errors.ParseError(_)) = config.from_file(filepath)
}
