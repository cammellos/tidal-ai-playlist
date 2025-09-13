pub type TidalAPIError {
  HttpError(String)
  ParseError(String)
  TidalDeviceAuthorizationExpiredError
  OtherError(String)
}
