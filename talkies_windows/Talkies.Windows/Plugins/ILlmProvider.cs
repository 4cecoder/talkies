using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace Talkies.Windows.Plugins
{
    /// <summary>
    /// Represents an available LLM model with its metadata.
    /// </summary>
    public class LlmModel
    {
        public string Name { get; set; } = string.Empty;
        public string DisplayName { get; set; } = string.Empty;
        public string? Description { get; set; }
        public long? SizeBytes { get; set; }
    }

    /// <summary>
    /// Interface for LLM providers (Ollama, LM Studio, etc.)
    /// </summary>
    public interface ILlmProvider
    {
        /// <summary>
        /// Gets the provider name (e.g., "Ollama", "LM Studio")
        /// </summary>
        string ProviderName { get; }

        /// <summary>
        /// Gets or sets the endpoint URL for the provider
        /// </summary>
        string Endpoint { get; set; }

        /// <summary>
        /// Gets or sets the currently selected model
        /// </summary>
        string SelectedModel { get; set; }

        /// <summary>
        /// Gets the available models from the provider
        /// </summary>
        List<LlmModel> AvailableModels { get; }

        /// <summary>
        /// Fetches available models from the provider endpoint
        /// </summary>
        Task<bool> FetchModelsAsync();

        /// <summary>
        /// Checks if the provider is available (endpoint is reachable)
        /// </summary>
        Task<bool> IsAvailableAsync();

        /// <summary>
        /// Enhances text using the selected model
        /// </summary>
        Task<string> EnhanceAsync(string text, EnhancementMode mode);

        /// <summary>
        /// Enhances text with a custom system prompt (bypasses predefined modes).
        /// </summary>
        Task<string> EnhanceWithPromptAsync(string text, string systemPrompt);

        /// <summary>
        /// Gets the temperature setting for the provider
        /// </summary>
        float Temperature { get; set; }

        /// <summary>
        /// Gets the TopP setting for the provider
        /// </summary>
        float TopP { get; set; }
    }
}
