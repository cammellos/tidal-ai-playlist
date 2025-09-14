import tidal_ai_playlist/internal/openai/config as openai_config
import tidal_ai_playlist/internal/tidal/types as tidal_types

pub type Config {
  Config(tidal_config: tidal_types.Config, openai_config: openai_config.Config)
}
