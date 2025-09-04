import gleam/io

@external(javascript, "./shim.js", "pad")
pub fn pad(str: String, len: Int, ch: String) -> String

pub fn main() -> Nil {
  let result = pad("42", 5, "0")
  io.print(result)
}
