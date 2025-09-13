import gleam/io

pub type TidalAPIError {
  HttpError(String)
  ParseError(String)
  UnexpectedResponseFormatError(String)
  TidalDeviceAuthorizationExpiredError
  TidalDeviceAuthorizationNotReady
  TidalRefreshTokenMissing
  TidalAccessTokenMissing
  TidalSessionIdMissing
  TidalUserIdMissing
  OtherError(String)
}

pub fn print_error(err: TidalAPIError) {
  case err {
    HttpError(reason) -> io.println("Http Error: " <> reason)
    ParseError(reason) -> io.println("Parse Error: " <> reason)
    TidalDeviceAuthorizationNotReady ->
      io.println("Tidal device authorization not ready")
    OtherError(reason) -> io.println("Other Error: " <> reason)
    UnexpectedResponseFormatError(reason) ->
      io.println("Unexpected response error: " <> reason)
    TidalDeviceAuthorizationExpiredError ->
      io.println("Device Authorization Expired")
    TidalRefreshTokenMissing -> io.println("Tidal refresh token missing")
    TidalAccessTokenMissing -> io.println("Tidal access token missing")
    TidalSessionIdMissing -> io.println("Tidal session-id missing")
    TidalUserIdMissing -> io.println("Tidal user-id missing")
  }
}
