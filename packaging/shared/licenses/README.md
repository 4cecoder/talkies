# Bundled license sources

These files are copied into platform release artifacts by their packaging
scripts. Keep upstream provenance here so maintainers can refresh a notice
when the corresponding bundled runtime is upgraded.

- `llama.cpp-MIT.txt`: llama.cpp source at
  `ggml-org/llama.cpp@53ed051ce5e8193652e449f43216ca3859454f49`, the pinned
  Linux release build revision. The Windows LLamaSharp runtime resolves its
  own source revision in its NuGet package metadata; its license text is also
  preserved separately as `LLamaSharp-MIT.txt`.
- `whisper.cpp-MIT.txt`: whisper.cpp source at
  `ggml-org/whisper.cpp@d09f61a708f3487afa956ff578e60eae5e7a233c`, the pinned
  Linux release build revision.
- `LLamaSharp-MIT.txt`: LLamaSharp source at
  `SciSharp/LLamaSharp@7cbbc45e421d55794d5050d126e0b96511007007`, matching
  the pinned NuGet 0.27.0 package.
- `NAudio-MIT.txt`: NAudio source at
  `naudio/NAudio@7c855e6737435f781dcbac782930a0de7a13cb2b`, matching the
  pinned NuGet 2.4.0 package.
- `MIT-LICENSE-TEXT.txt`: standard MIT permission and disclaimer text used
  with the exact copyright and author metadata collected from restored NuGet
  package manifests.
