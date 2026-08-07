## 0.0.6

**Breaking changes:**
* `SudachiDictionary` and `SudachiTokenizer` are now plain constructors with an async `init()` instance method instead of static factory methods.
* `SudachiDictionary.validateDictionary()` renamed to `SudachiDictionary.validateFile()`.

## 0.0.5

New feature: you can now validate if a `.dic` file is a Sudachi dictionary file.

## 0.0.4

Centralized module exports to allow importing from a single entry point.

## 0.0.3

* Update supported platforms.
* Update example.

## 0.0.2+2

Update hooks version.
* hooks: ^2.1.0 => ">=2.0.0 <=2.1.0"
   
## 0.0.2

Bump dependencies version.
* code_assets: ^1.0.0 => ^1.2.1
* ffi: ^2.1.4 => ^2.2.0
* ffigen: ^20.1.1 => ^21.0.0
* hooks: ^1.0.0 => ^2.1.0
* test: ^1.28.0 => ^1.31.2

## 0.0.1

* Initial release.
* Dart FFI wrapper around the Rust `sudachi.rs` morphological analyzer.
* `SudachiDictionary.init` — loads a Sudachi system dictionary on a background isolate.
* `SudachiTokenizer.init` / `tokenize` / `tokenizeAsync` — synchronous and async tokenization.
* `Morpheme` — surface, dictionary form, normalized form, reading, and part-of-speech tags.
* `Mode.a / b / c` — three split granularities.
* Supported platforms: macOS, Linux, Windows.
