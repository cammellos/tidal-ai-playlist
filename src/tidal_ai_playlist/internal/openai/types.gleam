pub type Content {
  Content(text: String)
}

pub type Output {
  Output(id: String, content: List(Content))
}

pub type Response {
  Response(id: String, output: List(Output))
}

pub type ResponsesInput {
  ResponsesInput(role: String, content: String)
}
