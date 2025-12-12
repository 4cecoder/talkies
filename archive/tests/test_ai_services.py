"""
Tests for AI services integration
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from whisper_cli.ai_services import improve_transcript, translate_text


def test_improve_transcript_openai(mocker):
    """Test transcript improvement with OpenAI"""
    text = "hello world this is a test"
    config = {
        "ai_services": {
            "openai_api_key": "test-key"
        }
    }

    mock_response = Mock()
    mock_response.choices = [Mock()]
    mock_response.choices[0].message.content = "Hello, world! This is a test."

    mock_client = Mock()
    mock_client.chat.completions.create.return_value = mock_response

    mock_openai_module = Mock()
    mock_openai_module.OpenAI.return_value = mock_client

    with patch.dict('sys.modules', {'openai': mock_openai_module}):
        result = improve_transcript(text, config)

    assert result == "Hello, world! This is a test."
    mock_client.chat.completions.create.assert_called_once()


def test_improve_transcript_openai_error_fallback(mocker):
    """Test that OpenAI errors fallback to next service"""
    text = "hello world"
    config = {
        "ai_services": {
            "openai_api_key": "test-key",
            "anthropic_api_key": "test-key-2"
        }
    }

    mock_openai_client = Mock()
    mock_openai_client.chat.completions.create.side_effect = Exception("OpenAI error")

    mock_anthropic_response = Mock()
    mock_anthropic_response.content = [Mock()]
    mock_anthropic_response.content[0].text = "Hello, world."

    mock_anthropic_client = Mock()
    mock_anthropic_client.messages.create.return_value = mock_anthropic_response

    mock_openai_module = Mock()
    mock_openai_module.OpenAI.return_value = mock_openai_client

    mock_anthropic_module = Mock()
    mock_anthropic_module.Anthropic.return_value = mock_anthropic_client

    with patch.dict('sys.modules', {'openai': mock_openai_module, 'anthropic': mock_anthropic_module}):
        result = improve_transcript(text, config)

    assert result == "Hello, world."
    mock_anthropic_client.messages.create.assert_called_once()


def test_improve_transcript_anthropic(mocker):
    """Test transcript improvement with Anthropic"""
    text = "hello world"
    config = {
        "ai_services": {
            "anthropic_api_key": "test-key"
        }
    }

    mock_response = Mock()
    mock_response.content = [Mock()]
    mock_response.content[0].text = "Hello, world."

    mock_client = Mock()
    mock_client.messages.create.return_value = mock_response

    mock_anthropic_module = Mock()
    mock_anthropic_module.Anthropic.return_value = mock_client

    with patch.dict('sys.modules', {'anthropic': mock_anthropic_module}):
        result = improve_transcript(text, config)

    assert result == "Hello, world."
    mock_client.messages.create.assert_called_once()


def test_improve_transcript_groq(mocker):
    """Test transcript improvement with Groq"""
    text = "hello world"
    config = {
        "ai_services": {
            "groq_api_key": "test-key"
        }
    }

    mock_response = Mock()
    mock_response.choices = [Mock()]
    mock_response.choices[0].message.content = "Hello, world."

    mock_client = Mock()
    mock_client.chat.completions.create.return_value = mock_response

    mock_groq_module = Mock()
    mock_groq_module.Groq.return_value = mock_client

    with patch.dict('sys.modules', {'groq': mock_groq_module}):
        result = improve_transcript(text, config)

    assert result == "Hello, world."
    mock_client.chat.completions.create.assert_called_once()


def test_improve_transcript_lmstudio(mocker):
    """Test transcript improvement with LM Studio"""
    text = "hello world"
    config = {
        "ai_services": {
            "lmstudio_url": "http://localhost:1234"
        }
    }

    mock_response = Mock()
    mock_response.choices = [Mock()]
    mock_response.choices[0].message.content = "Hello, world."

    mock_client = Mock()
    mock_client.chat.completions.create.return_value = mock_response

    mock_openai_module = Mock()
    mock_openai_module.OpenAI.return_value = mock_client

    with patch.dict('sys.modules', {'openai': mock_openai_module}):
        result = improve_transcript(text, config)

    assert result == "Hello, world."
    # Verify base_url was set correctly
    mock_openai_module.OpenAI.assert_called_once()
    call_args = mock_openai_module.OpenAI.call_args
    assert call_args[1]["base_url"] == "http://localhost:1234/v1"


def test_improve_transcript_ollama(mocker):
    """Test transcript improvement with Ollama"""
    text = "hello world"
    config = {
        "ai_services": {
            "ollama_url": "http://localhost:11434"
        }
    }

    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"message": {"content": "Hello, world."}}
    mock_response.raise_for_status = Mock()

    with patch('whisper_cli.ai_services.requests.post', return_value=mock_response):
        result = improve_transcript(text, config)

    assert result == "Hello, world."


def test_improve_transcript_no_service_available(mocker):
    """Test that original text is returned when no AI service is available"""
    text = "hello world"
    config = {
        "ai_services": {}
    }
    
    # Mock all services to fail
    with patch('whisper_cli.ai_services.requests.post', side_effect=Exception("Not available")):
        result = improve_transcript(text, config)
    
    assert result == text


def test_translate_text_openai(mocker):
    """Test translation with OpenAI"""
    text = "Hello, world"
    target_lang = "es"
    config = {
        "ai_services": {
            "openai_api_key": "test-key"
        }
    }

    mock_response = Mock()
    mock_response.choices = [Mock()]
    mock_response.choices[0].message.content = "Hola, mundo"

    mock_client = Mock()
    mock_client.chat.completions.create.return_value = mock_response

    mock_openai_module = Mock()
    mock_openai_module.OpenAI.return_value = mock_client

    with patch.dict('sys.modules', {'openai': mock_openai_module}):
        result = translate_text(text, target_lang, config)

    assert result == "Hola, mundo"
    mock_client.chat.completions.create.assert_called_once()


def test_translate_text_ollama(mocker):
    """Test translation with Ollama"""
    text = "Hello, world"
    target_lang = "es"
    config = {
        "ai_services": {
            "ollama_url": "http://localhost:11434"
        }
    }

    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"message": {"content": "Hola, mundo"}}
    mock_response.raise_for_status = Mock()

    with patch('whisper_cli.ai_services.requests.post', return_value=mock_response):
        result = translate_text(text, target_lang, config)

    assert result == "Hola, mundo"


def test_translate_text_no_service_available(mocker):
    """Test that original text is returned when no translation service is available"""
    text = "Hello, world"
    target_lang = "es"
    config = {
        "ai_services": {}
    }
    
    with patch('whisper_cli.ai_services.requests.post', side_effect=Exception("Not available")):
        result = translate_text(text, target_lang, config)
    
    assert result == text


# Removed: add_speakers_to_transcript moved to transcription module as add_speaker_labels

