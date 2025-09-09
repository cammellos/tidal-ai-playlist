import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string

pub fn error_to_string(error: json.DecodeError) -> String {
  case error {
    json.UnexpectedEndOfInput -> "unexpected end of input"
    json.UnexpectedByte(byte) -> "unexpected byte " <> byte
    json.UnexpectedSequence(seq) -> "unexpected sequence " <> seq
    json.UnableToDecode(errors) ->
      "unable to decode "
      <> string.join(list.map(errors, decode_error_to_string), ",")
  }
}

fn decode_error_to_string(error: decode.DecodeError) -> String {
  case error {
    decode.DecodeError(expected, found, path) ->
      "expected "
      <> expected
      <> " found "
      <> found
      <> " path "
      <> string.join(path, "-->")
  }
}
