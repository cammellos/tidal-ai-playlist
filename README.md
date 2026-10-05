# Tidal AI Playlist Generator

A command-line tool to create Tidal playlists using AI-generated music recommendations. Users provide a prompt describing their desired music, and the tool interacts with OpenAI to generate a playlist, which is then uploaded to Tidal.

## Features

- AI-powered music recommendations using OpenAI.
- Interactive playlist editing and confirmation.
- Automatic Tidal playlist creation with access token management.
- Input/output fully abstracted for easy testing and mocking.
- Configurable via environment variables or a local config file.

## Requirements

- **Tidal account**, you need a `client-id` and `client-secret`
- **OpenAI API key** for AI generation
- Unix-like or Windows system

## Setup

Set environment variables:

```bash
export OPENAI_API_KEY="your_openai_api_key"
export TIDAL_AI_PLAYLIST_CONFIG="/path/to/local/config.json"
export TIDAL_CLIENT_ID="client-id" // not needed if credentials are already stored on disk
export TIDAL_CLIENT_SECRET="client-secret" // not needed if credentials are already stored on disk
export TIDAL_REFRESH_TOKEN="refresh-token" // optional, a saved login (see `login` below)
export TIDAL_USER_ID="user-id" // optional, required with TIDAL_REFRESH_TOKEN
```

NOTE: it will save the values unencrypted on your filesystem. If you don't specify `TIDAL_AI_PLAYLIST_CONFIG` it will not save them.

## Running the Application

Run the interactive flow from the command line:

```bash
gleam run
```

You will have to login on tidal and copy the device code.

## Non-interactive commands

Every subcommand prints JSON on stdout, writes errors to stderr and exits non-zero on failure,
so it can be driven by scripts or agents:

```bash
tidal-ai-playlist search "angine de poitrine" --limit 5
tidal-ai-playlist list-playlists --limit 20
tidal-ai-playlist playlist-tracks <uuid>
tidal-ai-playlist favorites [tracks|albums|artists] --limit 20 --offset 0
tidal-ai-playlist create-playlist "My playlist" --description "..."
tidal-ai-playlist add <uuid> <track-id> <track-id>...
tidal-ai-playlist generate "african music like jeff buckley" --title "..."
```

These never start a device login. Log in once with
`tidal-ai-playlist login --output login.json` (the file is created with mode 0600), then pass
its values as `TIDAL_REFRESH_TOKEN` and `TIDAL_USER_ID`, e.g. from a secrets manager.
Tidal doesn't rotate the refresh token, so it stays valid.

## Nix

```bash
nix build          # result/bin/tidal-ai-playlist
nix run . -- help
```

When `manifest.toml` changes, update `outputHash` of the deps derivation in `flake.nix`.

## Testing

```bash
gleam test
```

## Contributing

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-feature`.
3. Commit your changes: `git commit -m "Add feature"`.
4. Push to the branch: `git push origin feature/my-feature`.
5. Create a Pull Request.

