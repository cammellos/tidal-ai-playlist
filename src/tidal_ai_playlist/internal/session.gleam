import gleam/option
import gleam/result

import tidal_ai_playlist/internal/errors
import tidal_ai_playlist/internal/tidal/api as tidal_api
import tidal_ai_playlist/internal/tidal/config as tidal_config
import tidal_ai_playlist/internal/tidal/types as tidal_types
import tidal_ai_playlist/internal/types

pub type Login {
  // Fall back to the device login when no refresh token is configured.
  AllowDeviceLogin
  // Fail instead, so non-interactive commands never wait on a browser.
  RequireSavedLogin
}

/// Loads the Tidal config (from `TIDAL_AI_PLAYLIST_CONFIG` or the environment)
/// and exchanges its refresh token for an access token.
pub fn load_tidal_config(
  dependencies: types.Dependencies,
  login: Login,
) -> Result(tidal_types.Config, errors.TidalAIPlaylistError) {
  let filepath_result = dependencies.get_env_fn("TIDAL_AI_PLAYLIST_CONFIG")

  use config <- result.try(case filepath_result {
    Ok(filepath) -> {
      case tidal_config.from_file(filepath) {
        Ok(config) -> Ok(config)
        Error(_) -> {
          tidal_config.from_env(dependencies.get_env_fn)
        }
      }
    }
    Error(Nil) -> tidal_config.from_env(dependencies.get_env_fn)
  })

  let config =
    config
    |> tidal_config.add_http_client(dependencies.http_client)
    |> tidal_config.add_output_fn(dependencies.output_fn)

  use #(refresh_token, user_id) <- result.try(
    case config.refresh_token, config.user_id, login {
      option.Some(refresh_token), option.Some(user_id), _ ->
        Ok(#(refresh_token, user_id))
      _, _, RequireSavedLogin -> Error(errors.TidalRefreshTokenMissing)
      _, _, AllowDeviceLogin ->
        case tidal_api.login(config) {
          Ok(oauth_token) ->
            Ok(#(oauth_token.refresh_token, oauth_token.user_id))
          Error(err) -> Error(err)
        }
    },
  )

  let config =
    config
    |> tidal_config.add_refresh_token(refresh_token)
    |> tidal_config.add_user_id(user_id)

  use access_token_response <- result.try(tidal_api.refresh_token(config))

  let config =
    config
    |> tidal_config.add_access_token(access_token_response.access_token)
    |> tidal_config.add_user_id(access_token_response.user_id)

  case filepath_result {
    Ok(filepath) -> tidal_config.to_file(config, filepath)
    _ -> Ok(config)
  }
}
