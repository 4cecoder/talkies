# CrispASR (pinned, upstream-owned)

[CrispASR](https://github.com/CrispStrobe/CrispASR) runs the Phonon-2 speech model through its
Parakeet TDT backend. Talkies uses it as the primary recognizer, with whisper.cpp as the fallback.

| Item | Pin |
| --- | --- |
| Release tag | `v0.8.43` |
| Tag object | `602a9888e7709a47edc988902ebeb34b0de41eb7` |
| Tagged commit | `eb633d908120cc5f44b8af8cd4aeb1191f16bfd8` |
| `include/crispasr_session.h` | SHA-256 `330c3d8d3ee5d6d4b1984d9fefedae504de28b7f616f88a27e76d747daf5cee9` |
| `LICENSE` (MIT) | SHA-256 `aa918fb53ff1948e12cdae8136e045210fb6db222a1f6f0c14bad48e6de2100e` |

Both files are copied unmodified from the tag. `crispasr_session.h` is generated upstream from the
`CA_EXPORT` definitions; do not edit it here. To update, replace both files from the new tag, update
this table, and update the release-asset pins in `../../build.zig.zon`.

## Runtime libraries

The shared libraries are not vendored. `build.zig` fetches the release archive for the target
architecture as a lazy, hash-pinned Zig dependency (see `build.zig.zon`) and installs it into
`lib/crispasr/`:

| Asset | SHA-256 |
| --- | --- |
| `libcrispasr-linux-x86_64.tar.gz` | `89ae56accb0b32450094d523594d93fd08bc07abe90b2c5b7102ef2c132001c3` |
| `libcrispasr-linux-arm64.tar.gz` | `b91a4bbe27d605cf3dc16bdaf2ac8af534e92efa1b27ccd90faeb2beb41d1f4b` |

The archive ships its own ggml (0.26.0) under the same sonames as the ggml Talkies bundles for
whisper.cpp and llama.cpp, and libcrispasr itself exports `whisper_*` symbols. Talkies therefore
never links it. `src/native/crispasr_runtime.c` loads it with `dlmopen(LM_ID_NEWLM)` into a separate
link-map namespace, so neither its ggml nor its `whisper_*` symbols can bind to Talkies' copies.

The archive also redistributes OpenBLAS (BSD-3-Clause) and GCC runtime libraries (`libgomp`,
`libgfortran`, and on x86_64 `libquadmath`). Their terms are in the archive's
`THIRD_PARTY_NOTICES.txt`, which is installed next to the libraries.
