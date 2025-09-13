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
