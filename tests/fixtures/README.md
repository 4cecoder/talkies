# Speech fixture

`jfk.wav` is the short JFK speech sample from the [`ggml-org/whisper.cpp` repository](https://github.com/ggml-org/whisper.cpp/blob/d09f61a708f3487afa956ff578e60eae5e7a233c/samples/jfk.wav),
revision `d09f61a708f3487afa956ff578e60eae5e7a233c`. The fixture is shared by
model-backed ASR and offline dictation acceptance tests on macOS, Windows, and Linux.

The shared S1-mini prompt contract lives at
[`linux/src/testdata/s1-mini-prompt-golden.json`](../../linux/src/testdata/s1-mini-prompt-golden.json).
macOS, Windows, and Linux tests consume it to verify identical Qwen chat framing,
all cleanup style and context values, both output structures, and trimming of
surrounding ASCII whitespace.

The local vocabulary prompt contract lives at
[`linux/src/testdata/local-vocabulary-golden.json`](../../linux/src/testdata/local-vocabulary-golden.json).
All three desktop test suites use it to check trimming, empty-term removal,
case-insensitive deduplication, first-spelling retention, and comma-separated
Whisper prompt formatting.
