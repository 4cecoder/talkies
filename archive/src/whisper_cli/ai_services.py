"""
AI services integration for transcript post-processing.

Supports multiple providers with automatic fallback:
- Cloud: OpenAI, Anthropic, Groq, DeepL
- Local: LM Studio, Ollama
"""

from typing import Dict, Any, Optional, List, Callable
from dataclasses import dataclass
from enum import Enum
import logging

import requests

logger = logging.getLogger(__name__)


class AIServiceError(Exception):
    """Raised when an AI service call fails."""
    pass


class NoAIServiceAvailableError(AIServiceError):
    """Raised when no AI service is available or configured."""
    pass


class AIProvider(Enum):
    """Supported AI providers."""
    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    GROQ = "groq"
    DEEPL = "deepl"
    LMSTUDIO = "lmstudio"
    OLLAMA = "ollama"


@dataclass
class AIServiceConfig:
    """Configuration for AI services."""
    # Cloud providers
    openai_api_key: Optional[str] = None
    openai_model: str = "gpt-4o-mini"

    anthropic_api_key: Optional[str] = None
    anthropic_model: str = "claude-3-5-haiku-latest"

    groq_api_key: Optional[str] = None
    groq_model: str = "llama-3.1-8b-instant"

    deepl_api_key: Optional[str] = None

    # Local providers
    lmstudio_url: str = "http://localhost:1234"
    lmstudio_model: str = "local-model"

    ollama_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.2"

    # Behavior
    timeout: int = 60
    fallback_enabled: bool = True
    preferred_provider: Optional[AIProvider] = None

    @classmethod
    def from_config(cls, config: Dict[str, Any]) -> "AIServiceConfig":
        """Create AIServiceConfig from config dictionary."""
        ai_config = config.get("ai_services", {})
        return cls(
            openai_api_key=ai_config.get("openai_api_key"),
            openai_model=ai_config.get("openai_model", cls.openai_model),
            anthropic_api_key=ai_config.get("anthropic_api_key"),
            anthropic_model=ai_config.get("anthropic_model", cls.anthropic_model),
            groq_api_key=ai_config.get("groq_api_key"),
            groq_model=ai_config.get("groq_model", cls.groq_model),
            deepl_api_key=ai_config.get("deepl_api_key"),
            lmstudio_url=ai_config.get("lmstudio_url", cls.lmstudio_url),
            lmstudio_model=ai_config.get("lmstudio_model", cls.lmstudio_model),
            ollama_url=ai_config.get("ollama_url", cls.ollama_url),
            ollama_model=ai_config.get("ollama_model", cls.ollama_model),
            timeout=ai_config.get("timeout", cls.timeout),
            fallback_enabled=ai_config.get("fallback_enabled", cls.fallback_enabled),
        )


# System prompts
IMPROVE_SYSTEM_PROMPT = """You are a transcription editor. Improve the punctuation, grammar, and formatting of this transcription to make it more readable.
- Fix obvious transcription errors
- Add proper punctuation and capitalization
- Break into paragraphs where appropriate
- Do NOT change the meaning or add content
- Return ONLY the improved text, no explanations."""

TRANSLATE_SYSTEM_PROMPT = """You are a translator. Translate the following text to {target_lang}.
- Preserve the original meaning and tone
- Use natural phrasing in the target language
- Return ONLY the translation, no explanations."""


def improve_transcript(
    text: str,
    config: Dict[str, Any],
    require_success: bool = False
) -> str:
    """Improve transcription using AI services.

    Tries providers in order: OpenAI -> Anthropic -> Groq -> LM Studio -> Ollama

    Args:
        text: The transcription text to improve.
        config: Configuration dictionary with 'ai_services' section.
        require_success: If True, raise exception if all providers fail.

    Returns:
        Improved text, or original text if all providers fail and require_success=False.

    Raises:
        NoAIServiceAvailableError: If require_success=True and all providers fail.
    """
    if not text or not text.strip():
        return text

    ai_config = AIServiceConfig.from_config(config)
    errors: List[str] = []

    # Define provider chain
    providers: List[tuple[str, Callable[[], str]]] = []

    if ai_config.openai_api_key:
        providers.append(("OpenAI", lambda: _improve_with_openai(text, ai_config)))

    if ai_config.anthropic_api_key:
        providers.append(("Anthropic", lambda: _improve_with_anthropic(text, ai_config)))

    if ai_config.groq_api_key:
        providers.append(("Groq", lambda: _improve_with_groq(text, ai_config)))

    # Local providers (always available to try)
    providers.append(("LM Studio", lambda: _improve_with_lmstudio(text, ai_config)))
    providers.append(("Ollama", lambda: _improve_with_ollama(text, ai_config)))

    # Try providers in order
    for provider_name, provider_func in providers:
        try:
            logger.debug(f"Trying {provider_name} for transcript improvement")
            result = provider_func()
            if result and result.strip():
                logger.info(f"Successfully improved transcript with {provider_name}")
                return result
        except Exception as e:
            error_msg = f"{provider_name}: {e}"
            errors.append(error_msg)
            logger.warning(f"AI service error - {error_msg}")

            if not ai_config.fallback_enabled:
                break

    # All providers failed
    if require_success:
        raise NoAIServiceAvailableError(
            f"All AI services failed:\n" + "\n".join(f"  - {e}" for e in errors)
        )

    logger.warning("No AI service available, returning original text")
    return text


def translate_text(
    text: str,
    target_lang: str,
    config: Dict[str, Any],
    require_success: bool = False
) -> str:
    """Translate text using AI services.

    Args:
        text: Text to translate.
        target_lang: Target language (e.g., 'Spanish', 'French', 'ja').
        config: Configuration dictionary.
        require_success: If True, raise exception if all providers fail.

    Returns:
        Translated text, or original if all providers fail.
    """
    if not text or not text.strip():
        return text

    ai_config = AIServiceConfig.from_config(config)
    errors: List[str] = []

    # DeepL is preferred for translation if available
    if ai_config.deepl_api_key:
        try:
            result = _translate_with_deepl(text, target_lang, ai_config)
            if result:
                logger.info("Successfully translated with DeepL")
                return result
        except Exception as e:
            errors.append(f"DeepL: {e}")
            logger.warning(f"DeepL translation error: {e}")

    # Fall back to LLM providers
    providers: List[tuple[str, Callable[[], str]]] = []

    if ai_config.openai_api_key:
        providers.append(("OpenAI", lambda: _translate_with_openai(text, target_lang, ai_config)))

    if ai_config.anthropic_api_key:
        providers.append(("Anthropic", lambda: _translate_with_anthropic(text, target_lang, ai_config)))

    if ai_config.groq_api_key:
        providers.append(("Groq", lambda: _translate_with_groq(text, target_lang, ai_config)))

    providers.append(("LM Studio", lambda: _translate_with_lmstudio(text, target_lang, ai_config)))
    providers.append(("Ollama", lambda: _translate_with_ollama(text, target_lang, ai_config)))

    for provider_name, provider_func in providers:
        try:
            logger.debug(f"Trying {provider_name} for translation")
            result = provider_func()
            if result and result.strip():
                logger.info(f"Successfully translated with {provider_name}")
                return result
        except Exception as e:
            errors.append(f"{provider_name}: {e}")
            logger.warning(f"Translation error - {provider_name}: {e}")

            if not ai_config.fallback_enabled:
                break

    if require_success:
        raise NoAIServiceAvailableError(
            f"All translation services failed:\n" + "\n".join(f"  - {e}" for e in errors)
        )

    logger.warning("No translation service available, returning original text")
    return text


# --- OpenAI ---

def _improve_with_openai(text: str, config: AIServiceConfig) -> str:
    """Improve text using OpenAI."""
    import openai

    client = openai.OpenAI(api_key=config.openai_api_key)
    response = client.chat.completions.create(
        model=config.openai_model,
        messages=[
            {"role": "system", "content": IMPROVE_SYSTEM_PROMPT},
            {"role": "user", "content": text}
        ],
        timeout=config.timeout
    )
    return response.choices[0].message.content


def _translate_with_openai(text: str, target_lang: str, config: AIServiceConfig) -> str:
    """Translate text using OpenAI."""
    import openai

    client = openai.OpenAI(api_key=config.openai_api_key)
    response = client.chat.completions.create(
        model=config.openai_model,
        messages=[
            {"role": "system", "content": TRANSLATE_SYSTEM_PROMPT.format(target_lang=target_lang)},
            {"role": "user", "content": text}
        ],
        timeout=config.timeout
    )
    return response.choices[0].message.content


# --- Anthropic ---

def _improve_with_anthropic(text: str, config: AIServiceConfig) -> str:
    """Improve text using Anthropic Claude."""
    import anthropic

    client = anthropic.Anthropic(api_key=config.anthropic_api_key)
    message = client.messages.create(
        model=config.anthropic_model,
        max_tokens=4096,
        system=IMPROVE_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": text}]
    )
    return message.content[0].text


def _translate_with_anthropic(text: str, target_lang: str, config: AIServiceConfig) -> str:
    """Translate text using Anthropic Claude."""
    import anthropic

    client = anthropic.Anthropic(api_key=config.anthropic_api_key)
    message = client.messages.create(
        model=config.anthropic_model,
        max_tokens=4096,
        system=TRANSLATE_SYSTEM_PROMPT.format(target_lang=target_lang),
        messages=[{"role": "user", "content": text}]
    )
    return message.content[0].text


# --- Groq ---

def _improve_with_groq(text: str, config: AIServiceConfig) -> str:
    """Improve text using Groq."""
    from groq import Groq

    client = Groq(api_key=config.groq_api_key)
    response = client.chat.completions.create(
        model=config.groq_model,
        messages=[
            {"role": "system", "content": IMPROVE_SYSTEM_PROMPT},
            {"role": "user", "content": text}
        ],
    )
    return response.choices[0].message.content


def _translate_with_groq(text: str, target_lang: str, config: AIServiceConfig) -> str:
    """Translate text using Groq."""
    from groq import Groq

    client = Groq(api_key=config.groq_api_key)
    response = client.chat.completions.create(
        model=config.groq_model,
        messages=[
            {"role": "system", "content": TRANSLATE_SYSTEM_PROMPT.format(target_lang=target_lang)},
            {"role": "user", "content": text}
        ],
    )
    return response.choices[0].message.content


# --- DeepL ---

def _translate_with_deepl(text: str, target_lang: str, config: AIServiceConfig) -> str:
    """Translate text using DeepL API."""
    # Map common language names to DeepL language codes
    lang_map = {
        "english": "EN",
        "german": "DE",
        "french": "FR",
        "spanish": "ES",
        "italian": "IT",
        "dutch": "NL",
        "polish": "PL",
        "portuguese": "PT",
        "russian": "RU",
        "japanese": "JA",
        "chinese": "ZH",
    }

    target_code = lang_map.get(target_lang.lower(), target_lang.upper())

    response = requests.post(
        "https://api-free.deepl.com/v2/translate",
        headers={"Authorization": f"DeepL-Auth-Key {config.deepl_api_key}"},
        data={
            "text": text,
            "target_lang": target_code,
        },
        timeout=config.timeout
    )
    response.raise_for_status()

    result = response.json()
    translations = result.get("translations", [])
    if translations:
        return translations[0].get("text", "")

    raise AIServiceError("DeepL returned no translations")


# --- LM Studio (OpenAI-compatible) ---

def _improve_with_lmstudio(text: str, config: AIServiceConfig) -> str:
    """Improve text using LM Studio (local)."""
    import openai

    client = openai.OpenAI(
        api_key="not-needed",
        base_url=f"{config.lmstudio_url}/v1"
    )
    response = client.chat.completions.create(
        model=config.lmstudio_model,
        messages=[
            {"role": "system", "content": IMPROVE_SYSTEM_PROMPT},
            {"role": "user", "content": text}
        ],
        timeout=config.timeout
    )
    return response.choices[0].message.content


def _translate_with_lmstudio(text: str, target_lang: str, config: AIServiceConfig) -> str:
    """Translate text using LM Studio (local)."""
    import openai

    client = openai.OpenAI(
        api_key="not-needed",
        base_url=f"{config.lmstudio_url}/v1"
    )
    response = client.chat.completions.create(
        model=config.lmstudio_model,
        messages=[
            {"role": "system", "content": TRANSLATE_SYSTEM_PROMPT.format(target_lang=target_lang)},
            {"role": "user", "content": text}
        ],
        timeout=config.timeout
    )
    return response.choices[0].message.content


# --- Ollama ---

def _improve_with_ollama(text: str, config: AIServiceConfig) -> str:
    """Improve text using Ollama (local)."""
    response = requests.post(
        f"{config.ollama_url}/api/chat",
        json={
            "model": config.ollama_model,
            "messages": [
                {"role": "system", "content": IMPROVE_SYSTEM_PROMPT},
                {"role": "user", "content": text}
            ],
            "stream": False
        },
        timeout=config.timeout
    )
    response.raise_for_status()

    result = response.json()
    return result.get("message", {}).get("content", "")


def _translate_with_ollama(text: str, target_lang: str, config: AIServiceConfig) -> str:
    """Translate text using Ollama (local)."""
    response = requests.post(
        f"{config.ollama_url}/api/chat",
        json={
            "model": config.ollama_model,
            "messages": [
                {"role": "system", "content": TRANSLATE_SYSTEM_PROMPT.format(target_lang=target_lang)},
                {"role": "user", "content": text}
            ],
            "stream": False
        },
        timeout=config.timeout
    )
    response.raise_for_status()

    result = response.json()
    return result.get("message", {}).get("content", "")


# --- Utility Functions ---

def check_ai_services(config: Dict[str, Any]) -> Dict[str, bool]:
    """Check which AI services are available.

    Returns:
        Dictionary mapping provider names to availability status.
    """
    ai_config = AIServiceConfig.from_config(config)
    status = {}

    # Check cloud providers (just API key presence)
    status["openai"] = bool(ai_config.openai_api_key)
    status["anthropic"] = bool(ai_config.anthropic_api_key)
    status["groq"] = bool(ai_config.groq_api_key)
    status["deepl"] = bool(ai_config.deepl_api_key)

    # Check local providers (actual connectivity)
    try:
        response = requests.get(
            f"{ai_config.lmstudio_url}/v1/models",
            timeout=2
        )
        status["lmstudio"] = response.status_code == 200
    except Exception:
        status["lmstudio"] = False

    try:
        response = requests.get(
            f"{ai_config.ollama_url}/api/tags",
            timeout=2
        )
        status["ollama"] = response.status_code == 200
    except Exception:
        status["ollama"] = False

    return status
