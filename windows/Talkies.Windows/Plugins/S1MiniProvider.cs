using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using LLama;
using LLama.Common;
using LLama.Sampling;
using Talkies.Windows.Services;

namespace Talkies.Windows.Plugins;

/// <summary>Runs S1-mini locally with the CPU backend. Transcript content is never sent to a service.</summary>
public sealed class S1MiniProvider : ILlmProvider, IDisposable
{
    private readonly S1MiniModelStore _store;
    private readonly SemaphoreSlim _inferenceLock = new(1, 1);
    private List<LlmModel> _models = new();
    private LLamaWeights? _weights;

    public event Action<string, double, bool>? StatusChanged;

    public S1MiniProvider(S1MiniModelStore? store = null) => _store = store ?? new S1MiniModelStore();

    public string ProviderName => "S1-mini (on-device)";
    public string Endpoint { get; set; } = string.Empty;
    public string SelectedModel { get; set; } = S1MiniModelStore.ModelFileName;
    public List<LlmModel> AvailableModels => _models;
    public float Temperature { get; set; } = 0.0f;
    public float TopP { get; set; } = 0.9f;
    public Task<bool> IsAvailableAsync() => Task.FromResult(true);

    public Task<bool> FetchModelsAsync(bool silent = false)
    {
        _models = new List<LlmModel>
        {
            new() { Name = S1MiniModelStore.ModelFileName, DisplayName = "S1-mini · English cleanup · CPU", Description = "Downloads once (about 462 MiB), then runs fully offline", SizeBytes = S1MiniModelStore.ModelSize }
        };
        return Task.FromResult(true);
    }

    public Task<string> EnhanceAsync(string text, EnhancementMode mode) => CleanAsync(text, mode, S1MiniPrompt.SystemPrompt);

    public Task<string> EnhanceWithPromptAsync(string text, string systemPrompt) => CleanAsync(text, EnhancementMode.Grammar, string.IsNullOrWhiteSpace(systemPrompt) ? S1MiniPrompt.SystemPrompt : systemPrompt);

    private async Task<string> CleanAsync(string text, EnhancementMode mode, string systemPrompt)
    {
        if (string.IsNullOrWhiteSpace(text)) return text;
        await _inferenceLock.WaitAsync().ConfigureAwait(false);
        try
        {
            StatusChanged?.Invoke("Verifying the on-device cleanup model", 0, true);
            var needsDownload = !_store.IsInstalled;
            if (needsDownload) StatusChanged?.Invoke("Downloading S1-mini for local cleanup", 0, true);
            var modelPath = await _store.EnsureInstalledAsync(new Progress<double>(fraction =>
                StatusChanged?.Invoke("Downloading S1-mini for local cleanup", fraction, false))).ConfigureAwait(false);
            if (needsDownload) StatusChanged?.Invoke("Loading S1-mini on the CPU", 1, true);
            var parameters = new ModelParams(modelPath) { ContextSize = 4096, GpuLayerCount = 0 };
            var weights = _weights ??= LLamaWeights.LoadFromFile(parameters);
            var executor = new StatelessExecutor(weights, parameters);
            var options = OptionsFor(mode);
            var rendered = systemPrompt == S1MiniPrompt.SystemPrompt
                ? S1MiniPrompt.Render(text, options.style, options.structure, options.context)
                : $"<|im_start|>system\n{systemPrompt}\nOutput only the cleaned transcript.<|im_end|>\n<|im_start|>user\n{text}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n";
            var inference = new InferenceParams
            {
                MaxTokens = Math.Clamp(text.Length * 2, 256, 2048),
                SamplingPipeline = new DefaultSamplingPipeline { Temperature = Temperature, TopP = TopP },
                AntiPrompts = new[] { "<|im_end|>", "<|im_start|>" }
            };
            var result = new System.Text.StringBuilder();
            await foreach (var token in executor.InferAsync(rendered, inference).ConfigureAwait(false)) result.Append(token);
            return S1MiniOutput.Resolve(text, result.ToString());
        }
        finally { _inferenceLock.Release(); }
    }

    public void Dispose()
    {
        _weights?.Dispose();
        _inferenceLock.Dispose();
    }

    private static (string style, string structure, string context) OptionsFor(EnhancementMode mode) => mode switch
    {
        EnhancementMode.Technical => ("formal", "prose", "general"),
        EnhancementMode.Concise => ("semi-casual", "prose", "general"),
        EnhancementMode.Creative => ("casual", "prose", "general"),
        EnhancementMode.Companion => ("semi-casual", "prose", "general"),
        _ => ("semi-formal", "prose", "general")
    };
}
