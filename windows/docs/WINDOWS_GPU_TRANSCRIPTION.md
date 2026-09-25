# Windows Whisper GPU runtime

Talkies uses Whisper.net with GGML Whisper models. Its Windows project includes
the upstream CUDA 13, CUDA 12, Vulkan, and CPU runtime packages. Whisper.net
tries the compatible runtimes in that order and exposes the runtime it loaded;
Talkies displays that actual runtime during transcription instead of inferring
GPU use from a GPU name or the presence of `nvcuda.dll`.

The package's documented runtime requirements are CUDA Toolkit 13.0.1 or newer
for CUDA 13, CUDA Toolkit 12.4.1 or newer for CUDA 12, and Vulkan Toolkit
1.4.321.1 or newer for Vulkan. CPU runtimes remain available when no compatible
GPU runtime is found. Native runtime selection is process-wide after the first
Whisper factory is created.

## DirectML status

Whisper.net does not provide a DirectML runtime for this GGML model path. The
DirectML proposal in issue #42 would require a separate ONNX Whisper model,
audio preprocessing, tokenizer, and inference implementation. Talkies does not
claim DirectML support; Vulkan is the available cross-vendor GPU route in
Whisper.net.

## Validation still required

Automated tests cover runtime ordering and truthful backend labels. A Windows
machine with each supported driver stack is still required to confirm real GPU
execution and benchmark latency. The upstream loader's compatibility checks
allow CPU fallback when a GPU runtime is unavailable, but they cannot guarantee
recovery from every native GPU driver or allocation crash after a runtime has
started. Until CUDA and Vulkan hardware runs are recorded, this remains a
hardware validation limitation rather than a claimed performance result.

## Upstream references

- [Whisper.net runtime packages and automatic runtime selection](https://github.com/sandrohanea/whisper.net#multiple-runtimes-support)
- [Whisper.net CUDA runtime requirements](https://github.com/sandrohanea/whisper.net#whispernetruntimecuda)
- [Whisper.net Vulkan runtime requirements](https://github.com/sandrohanea/whisper.net#whispernetruntimevulkan)
- [Whisper.net `RuntimeOptions`](https://github.com/sandrohanea/whisper.net/blob/main/Whisper.net/LibraryLoader/RuntimeOptions.cs)
