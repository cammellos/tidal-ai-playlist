import gleam/http
import gleam/http/request

import tidal_ai_playlist/internal/tidal/config

const base_auth_host = "auth.tidal.com"

const device_authorization_path = "/v1/oauth2/device_authorization"

const scope = "r_usr w_usr w_sub"

const device_code_grant_type = "urn:ietf:params:oauth:grant-type:device_code"

const user_agent = "Mozilla/5.0 (Linux; Android 12; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/91.0.4472.114 Safari/537.36"

const client_version = "2025.7.16"

const token_path = "/v1/oauth2/token"

pub fn authorize_device(client_id: String) -> request.Request(String) {
  let body = "client_id=" <> client_id <> "&scope=r_usr w_usr w_sub"
  base_auth_client()
  |> request.set_path(device_authorization_path)
  |> request.set_body(body)
  |> request.prepend_header("Content-Type", "application/x-www-form-urlencoded")
  |> request.set_method(http.Post)
}

pub fn exchange_device_code_for_token(
  config: config.Config,
  device_code: String,
) -> request.Request(String) {
  let body =
    "client_id="
    <> config.client_id
    <> "&scope="
    <> scope
    <> "&client_secret="
    <> config.client_secret
    <> "&device_code="
    <> device_code
    <> "&grant_type="
    <> device_code_grant_type
  base_auth_client()
  |> request.set_path(token_path)
  |> request.prepend_header("Content-Type", "application/x-www-form-urlencoded")
  |> request.set_method(http.Post)
  |> request.set_body(body)
}

pub fn exchange_refresh_token(
  config: config.Config,
  refresh_token: String,
) -> request.Request(String) {
  let body =
    "grant_type=refresh_token&refresh_token="
    <> refresh_token
    <> "&client_id="
    <> config.client_id
    <> "&client_secret="
    <> config.client_secret
  base_auth_client()
  |> request.set_path(token_path)
  |> request.prepend_header("Content-Type", "application/x-www-form-urlencoded")
  |> request.set_method(http.Post)
  |> request.set_body(body)
}

fn base_auth_client() -> request.Request(String) {
  request.new()
  |> request.set_scheme(http.Https)
  |> request.prepend_header("User-Agent", user_agent)
  |> request.prepend_header("x-tidal-client-version", client_version)
  |> request.set_host(base_auth_host)
}
