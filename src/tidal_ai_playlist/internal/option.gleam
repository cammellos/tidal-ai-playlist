import gleam/option

pub fn from_option(opt: option.Option(a), error: e) -> Result(a, e) {
  case opt {
    option.Some(value) -> Ok(value)
    option.None -> Error(error)
  }
}
