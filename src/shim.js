import OpenAI from "openai";
import readline from "readline";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function askQuestion(question) {
  return new Promise((resolve) => {
    rl.question(question, resolve);
  });
}

export async function ask(text) {
  const answer = await askQuestion(text);

  const response = await client.responses.create({
    model: "gpt-4o",
    instructions: "You are a helpful music recommendation assistant. Suggest music based on the user's preferences, mood, or context. Provide a mix of well-known tracks and hidden gems, with short explanations. Please provide playlist in an importable format, so no markdown, just artist and song title. No extra text.",
    input: answer,
  });

  rl.close();

  return response.output_text;
}
