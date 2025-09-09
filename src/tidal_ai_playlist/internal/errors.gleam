pub type TidalError {
  HttpError(String)
  ParseError(String)
  TidalDeviceAuthorizationExpiredError
  OtherError(String)
}
