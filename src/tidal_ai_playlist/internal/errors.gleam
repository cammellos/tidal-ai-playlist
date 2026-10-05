import gleam/int
import gleam/io

pub type TidalAIPlaylistError {
  HttpError(String)
  ParseError(String)
  UnexpectedResponseFormatError(String)
  TidalDeviceAuthorizationExpiredError
  TidalDeviceAuthorizationNotReady
  TidalRefreshTokenMissing
  TidalAccessTokenMissing
  TidalSessionIdMissing
  TidalUserIdMissing
  TidalCredentialsMissing
  TidalReadingConfigError
  TidalWritingConfigError
  MaxNumberOfOpenAIRetries
  OpenAICredentialsMissing
  OtherError(String)
  TidalApiError(status: Int, body: String)
}

pub fn print_error(err: TidalAIPlaylistError) {
  io.println(error_to_string(err))
}

pub fn error_to_string(err: TidalAIPlaylistError) -> String {
  case err {
    HttpError(reason) -> "Http Error: " <> reason
    ParseError(reason) -> "Parse Error: " <> reason
    TidalDeviceAuthorizationNotReady -> "Tidal device authorization not ready"
    OtherError(reason) -> "Other Error: " <> reason
    UnexpectedResponseFormatError(reason) ->
      "Unexpected response error: " <> reason
    TidalDeviceAuthorizationExpiredError -> "Device Authorization Expired"
    TidalRefreshTokenMissing ->
      "Tidal refresh token missing (set TIDAL_REFRESH_TOKEN and TIDAL_USER_ID, or run `login`)"
    TidalAccessTokenMissing -> "Tidal access token missing"
    TidalSessionIdMissing -> "Tidal session-id missing"
    TidalUserIdMissing -> "Tidal user-id missing"
    TidalCredentialsMissing -> "Tidal credentials missing"
    TidalReadingConfigError -> "Error reading credentials file"
    TidalWritingConfigError -> "Error writing credentials file"
    OpenAICredentialsMissing -> "OpenAI credentials missing"
    MaxNumberOfOpenAIRetries -> "max number of openai retries"
    TidalApiError(status, body) ->
      "Tidal API returned " <> int.to_string(status) <> ": " <> body
  }
}
