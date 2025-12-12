"""
Configuration management for Whisper CLI.

Handles loading, saving, and validating configuration from TOML files.
"""

from pathlib import Path
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, field
import logging
import os
import re

import toml

logger = logging.getLogger(__name__)


class ConfigError(Exception):
    """Raised when configuration is invalid."""
    pass


# Valid Whisper model names
VALID_WHISPER_MODELS = {
    "tiny", "tiny.en",
    "base", "base.en",
    "small", "small.en",
    "medium", "medium.en",
    "large", "large-v1", "large-v2", "large-v3",
    "distil-large-v2", "distil-large-v3",
}

# Valid compute types for faster-whisper
VALID_COMPUTE_TYPES = {
    "int8", "int8_float16", "int8_bfloat16",
    "int16", "float16", "bfloat16", "float32",
}

# Valid devices
VALID_DEVICES = {"cpu", "cuda", "auto"}

# Valid output formats
VALID_OUTPUT_FORMATS = {"txt", "srt", "vtt", "json"}


DEFAULT_CONFIG: Dict[str, Any] = {
    "whisper": {
        "model": "base",
        "language": None,
        "device": "auto",
        "compute_type": "int8",
    },
    "ai_services": {
        "openai_api_key": None,
        "openai_model": "gpt-4o-mini",
        "anthropic_api_key": None,
        "anthropic_model": "claude-3-5-haiku-latest",
        "groq_api_key": None,
        "groq_model": "llama-3.1-8b-instant",
        "deepl_api_key": None,
        "ollama_url": "http://localhost:11434",
        "ollama_model": "llama3.2",
        "lmstudio_url": "http://localhost:1234",
        "lmstudio_model": "local-model",
        "timeout": 60,
        "fallback_enabled": True,
    },
    "output": {
        "format": "txt",
        "directory": None,  # None = same directory as input
    },
    "recording": {
        "sample_rate": 16000,
        "channels": 1,
        "device": None,  # None = default device
    },
    "batch": {
        "recursive": False,
        "pattern": "*.mp3,*.wav,*.m4a,*.flac,*.ogg,*.aac",
        "parallel": 1,
    },
}


def load_config(config_path: Optional[Path] = None) -> Dict[str, Any]:
    """Load configuration from TOML file.

    Args:
        config_path: Path to config file. If None, uses ~/.whisper-cli.toml

    Returns:
        Merged configuration dictionary.

    Raises:
        ConfigError: If configuration is invalid.
    """
    if config_path is None:
        config_path = Path.home() / ".whisper-cli.toml"

    config_path = Path(config_path).expanduser()

    # Start with defaults
    config = _deep_copy(DEFAULT_CONFIG)

    # Load user config if exists
    if config_path.exists():
        try:
            with open(config_path, "r") as f:
                user_config = toml.load(f)
            _deep_update(config, user_config)
            logger.debug(f"Loaded config from {config_path}")
        except toml.TomlDecodeError as e:
            raise ConfigError(f"Invalid TOML in {config_path}: {e}")
        except Exception as e:
            raise ConfigError(f"Failed to load {config_path}: {e}")
    else:
        # Apply system-optimized defaults
        try:
            from .system_detect import get_recommended_config
            recommended = get_recommended_config()
            if recommended:
                _deep_update(config, recommended)
                logger.debug("Applied system-recommended configuration")
        except ImportError:
            pass

    # Load API keys from environment variables
    _load_env_vars(config)

    # Validate configuration
    validate_config(config)

    return config


def _load_env_vars(config: Dict[str, Any]) -> None:
    """Load API keys from environment variables if not set in config."""
    env_mappings = {
        "OPENAI_API_KEY": ("ai_services", "openai_api_key"),
        "ANTHROPIC_API_KEY": ("ai_services", "anthropic_api_key"),
        "GROQ_API_KEY": ("ai_services", "groq_api_key"),
        "DEEPL_API_KEY": ("ai_services", "deepl_api_key"),
    }

    for env_var, (section, key) in env_mappings.items():
        if not config.get(section, {}).get(key):
            env_value = os.environ.get(env_var)
            if env_value:
                if section not in config:
                    config[section] = {}
                config[section][key] = env_value
                logger.debug(f"Loaded {key} from ${env_var}")


def validate_config(config: Dict[str, Any]) -> List[str]:
    """Validate configuration and return list of warnings.

    Args:
        config: Configuration dictionary to validate.

    Returns:
        List of warning messages (non-fatal issues).

    Raises:
        ConfigError: If configuration has fatal errors.
    """
    warnings = []

    # Validate whisper section
    whisper = config.get("whisper", {})

    model = whisper.get("model", "base")
    if model not in VALID_WHISPER_MODELS:
        raise ConfigError(
            f"Invalid whisper model: '{model}'. "
            f"Valid models: {', '.join(sorted(VALID_WHISPER_MODELS))}"
        )

    device = whisper.get("device", "auto")
    if device not in VALID_DEVICES:
        raise ConfigError(
            f"Invalid device: '{device}'. Valid devices: {', '.join(VALID_DEVICES)}"
        )

    compute_type = whisper.get("compute_type", "int8")
    if compute_type not in VALID_COMPUTE_TYPES:
        raise ConfigError(
            f"Invalid compute_type: '{compute_type}'. "
            f"Valid types: {', '.join(sorted(VALID_COMPUTE_TYPES))}"
        )

    # Validate output section
    output = config.get("output", {})
    fmt = output.get("format", "txt")
    if fmt not in VALID_OUTPUT_FORMATS:
        raise ConfigError(
            f"Invalid output format: '{fmt}'. "
            f"Valid formats: {', '.join(VALID_OUTPUT_FORMATS)}"
        )

    # Validate recording section
    recording = config.get("recording", {})
    sample_rate = recording.get("sample_rate", 16000)
    if not isinstance(sample_rate, int) or sample_rate < 8000 or sample_rate > 48000:
        warnings.append(f"Unusual sample_rate: {sample_rate}. Typical values: 16000, 44100, 48000")

    channels = recording.get("channels", 1)
    if not isinstance(channels, int) or channels < 1 or channels > 2:
        raise ConfigError(f"Invalid channels: {channels}. Must be 1 or 2.")

    # Validate ai_services URLs
    ai_services = config.get("ai_services", {})
    for url_key in ["ollama_url", "lmstudio_url"]:
        url = ai_services.get(url_key)
        if url and not _is_valid_url(url):
            warnings.append(f"Invalid URL for {url_key}: {url}")

    # Validate timeout
    timeout = ai_services.get("timeout", 60)
    if not isinstance(timeout, (int, float)) or timeout <= 0:
        warnings.append(f"Invalid timeout: {timeout}. Using default 60s.")
        config["ai_services"]["timeout"] = 60

    return warnings


def _is_valid_url(url: str) -> bool:
    """Check if URL is valid."""
    pattern = re.compile(
        r'^https?://'  # http:// or https://
        r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'  # domain
        r'localhost|'  # localhost
        r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'  # IP
        r'(?::\d+)?'  # optional port
        r'(?:/?|[/?]\S+)$', re.IGNORECASE)
    return bool(pattern.match(url))


def save_config(config: Dict[str, Any], config_path: Optional[Path] = None) -> Path:
    """Save configuration to TOML file.

    Args:
        config: Configuration dictionary to save.
        config_path: Path to save to. If None, uses ~/.whisper-cli.toml

    Returns:
        Path where config was saved.
    """
    if config_path is None:
        config_path = Path.home() / ".whisper-cli.toml"

    config_path = Path(config_path).expanduser()
    config_path.parent.mkdir(parents=True, exist_ok=True)

    # Remove None values for cleaner output
    clean_config = _remove_none_values(config)

    with open(config_path, "w") as f:
        toml.dump(clean_config, f)

    logger.info(f"Saved configuration to {config_path}")
    return config_path


def _remove_none_values(d: Dict) -> Dict:
    """Recursively remove None values from dictionary."""
    result = {}
    for k, v in d.items():
        if isinstance(v, dict):
            nested = _remove_none_values(v)
            if nested:  # Only add non-empty dicts
                result[k] = nested
        elif v is not None:
            result[k] = v
    return result


def _deep_copy(d: Dict) -> Dict:
    """Deep copy a dictionary."""
    result = {}
    for k, v in d.items():
        if isinstance(v, dict):
            result[k] = _deep_copy(v)
        elif isinstance(v, list):
            result[k] = v.copy()
        else:
            result[k] = v
    return result


def _deep_update(base: Dict, update: Dict) -> None:
    """Deep update a dictionary in place."""
    for key, value in update.items():
        if isinstance(value, dict) and key in base and isinstance(base[key], dict):
            _deep_update(base[key], value)
        else:
            base[key] = value


def get_config_path() -> Path:
    """Get the default configuration file path."""
    return Path.home() / ".whisper-cli.toml"


def create_default_config(config_path: Optional[Path] = None) -> Path:
    """Create a default configuration file with comments.

    Args:
        config_path: Path to create config at. If None, uses default.

    Returns:
        Path where config was created.
    """
    if config_path is None:
        config_path = get_config_path()

    config_path = Path(config_path).expanduser()

    if config_path.exists():
        raise ConfigError(f"Config file already exists: {config_path}")

    config_content = '''# Whisper CLI Configuration
# https://github.com/yourusername/whisper-cli

[whisper]
# Whisper model: tiny, base, small, medium, large-v2, large-v3
model = "base"
# Device: auto, cpu, cuda
device = "auto"
# Compute type: int8, float16, float32
compute_type = "int8"
# Language code (e.g., "en", "es", "fr") or null for auto-detect
# language = "en"

[ai_services]
# API keys (can also be set via environment variables)
# openai_api_key = "sk-..."
# anthropic_api_key = "sk-ant-..."
# groq_api_key = "gsk_..."
# deepl_api_key = "..."

# Model names (optional, defaults shown)
# openai_model = "gpt-4o-mini"
# anthropic_model = "claude-3-5-haiku-latest"
# groq_model = "llama-3.1-8b-instant"

# Local AI servers
ollama_url = "http://localhost:11434"
ollama_model = "llama3.2"
lmstudio_url = "http://localhost:1234"

# Timeout for AI service calls (seconds)
timeout = 60
# Enable fallback to next provider on failure
fallback_enabled = true

[output]
# Default output format: txt, srt, vtt, json
format = "txt"
# Output directory (null = same as input file)
# directory = "/path/to/transcripts"

[recording]
# Audio recording settings
sample_rate = 16000
channels = 1
# Specific device name (null = default)
# device = "MacBook Pro Microphone"

[batch]
# Batch processing settings
recursive = false
pattern = "*.mp3,*.wav,*.m4a,*.flac,*.ogg,*.aac"
parallel = 1
'''

    config_path.parent.mkdir(parents=True, exist_ok=True)
    with open(config_path, "w") as f:
        f.write(config_content)

    logger.info(f"Created default config at {config_path}")
    return config_path
