import gleam/io
import gleam/javascript/promise

@external(javascript, "./shim.js", "ask")
pub fn ask(text: String) -> promise.Promise(String)

pub fn main() -> Nil {
  let question = "Hello, what would you like to listen to today?"
  let program =
    ask(question)
    |> promise.await(fn(answer) {
      io.println(answer)
      promise.resolve(answer)
    })
  Nil
}
