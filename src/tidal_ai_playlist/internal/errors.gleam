pub type TidalAPIError {
  HttpError(String)
  ParseError(String)
  UnexpectedResponseFormatError(String)
  TidalDeviceAuthorizationExpiredError
  OtherError(String)
}
