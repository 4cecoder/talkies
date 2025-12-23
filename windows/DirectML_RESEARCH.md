# DirectML Support Research

## Summary

DirectML provides GPU acceleration for Whisper on Windows across AMD, Intel, and NVIDIA GPUs. However, **whisper.net does not currently support DirectML directly** - it only supports CUDA for NVIDIA GPUs.

## DirectML Options

### Option 1: ONNX Runtime + DirectML
- Convert Whisper models to ONNX format
- Use `Microsoft.ML.OnnxRuntime.DirectML` NuGet package
- Supports AMD, Intel, NVIDIA GPUs via DirectX 12
- **Requires model conversion from GGML to ONNX**

### Option 2: Wait for whisper.net DirectML Support
- whisper.net currently only supports CUDA
- GitHub issue tracking: https://github.com/sandrohanea/whisper.net
- No active DirectML implementation at this time

### Option 3: Alternative Libraries
- **OpenVINO**: Intel CPU/GPU/NPU support
  - `pip install openvino-genai`
  - Optimize and run Whisper on Intel hardware
- **whisper.cpp**: Multiple backends
  - `-DWHISPER_OPENVINO=ON` for OpenVINO
  - ROCm support for AMD GPUs (Linux only)
- **Microsoft DirectML**:
  - Python implementation with ONNX Runtime DirectML
  - Example: `onnxruntime-directml` package

## Current Implementation Status

### Implemented (Issue #42)
- ✅ NVIDIA CUDA support via `Whisper.net.CUDA` package
- ✅ GPU detection via `CudaDetector`
- ✅ User preference setting (`PreferGpu`)
- ✅ CPU fallback when GPU unavailable
- ✅ `.WithCuda()` API usage

### Not Yet Implemented
- ❌ AMD GPU support (DirectML)
- ❌ Intel GPU support (DirectML or OpenVINO)
- ❌ Intel NPU support (OpenVINO)

## Recommended Future Approach

### For AMD/Intel GPUs:
1. **DirectML via ONNX Runtime** (Cross-vendor):
   - Convert GGML models to ONNX using `optimum-cli`
   - Use `Microsoft.ML.OnnxRuntime.DirectML` package
   - Create separate transcription service: `DirectMLTranscriptionService`

2. **OpenVINO for Intel Hardware**:
   - Use `openvino-genai` Python backend or C# bindings
   - Optimized for Intel GPUs and NPUs
   - Better performance than DirectML on Intel hardware

### Code Example (Future Implementation):
```csharp
// DirectML transcription service (not implemented)
public class DirectMLTranscriptionService : ITranscriptionService
{
    public async Task<TranscriptionResult> TranscribeAsync(...)
    {
        // Use ONNX Runtime with DirectML EP
        var sessionOptions = new SessionOptions();
        sessionOptions.AppendExecutionProvider_DML(deviceId: 0);
        
        using var session = new InferenceSession("whisper-base.onnx", sessionOptions);
        // ... inference logic
    }
}
```

## References

- [ONNX Runtime DirectML Execution Provider](https://onnxruntime.ai/docs/execution-providers/DirectML-ExecutionProvider.html)
- [Whisper on AMD GPUs with ROCm](https://rocm.blogs.amd.com/artificial-intelligence/whisper/README.html)
- [Whisper on Ryzen AI NPUs](https://www.amd.com/en/developer/resources/technical-articles/2025/unlocking-on-device-asr-with-whisper-on-ryzen-ai-npus.html)
- [OpenVINO Whisper](https://blog.openvino.ai/blog-posts/optimizing-whisper-and-distil-whisper-for-speech-recognition-with-openvino)
- [whisper.net GitHub](https://github.com/sandrohanea/whisper.net)
