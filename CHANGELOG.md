## 0.0.1

* Initial release.
* Dart FFI wrapper around the Rust `sudachi.rs` morphological analyzer.
* `SudachiDictionary.init` — loads a Sudachi system dictionary on a background isolate.
* `SudachiTokenizer.init` / `tokenize` / `tokenizeAsync` — synchronous and async tokenization.
* `Morpheme` — surface, dictionary form, normalized form, reading, and part-of-speech tags.
* `Mode.a / b / c` — three split granularities.
* Supported platforms: macOS, Linux, Windows.
