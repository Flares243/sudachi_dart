# sudachi_dart

A Flutter FFI plugin for Japanese morphological analysis using [Sudachi](https://github.com/WorksApplications/sudachi.rs). Wraps the Rust `sudachi.rs` library via a C FFI layer.

## Platform support

| Platform | Supported |
|----------|-----------|
| macOS    | ✓         |
| Windows  | ✓         |
| Linux    | ✗         |
| iOS      | ✗         |
| Android  | ✗         |

## Requirements

- [Rust toolchain](https://rustup.rs) — the native library is built from source at compile time.
- A Sudachi system dictionary (`.dic` file) — **not bundled**, see [Dictionary](#dictionary) below.

## Usage

```dart
import 'package:sudachi_dart/sudachi_dart.dart';

final dict = await SudachiDictionary.init(
  configPath: '/path/to/sudachi.json',
  dictionaryPath: '/path/to/system_full.dic',
);

final tokenizer = await SudachiTokenizer.init(dict);

final morphemes = await tokenizer.tokenize('東京都に住む', mode: Mode.c);

for (final m in morphemes) {
  print('${m.surface} [${m.readingForm}] ${m.partOfSpeech.take(2).join('-')}');
}

// Free native resources when done.
tokenizer.dispose();
dict.dispose();
```

### Split modes

| Mode | Granularity |
|------|-------------|
| `Mode.a` | Short / atomic units |
| `Mode.b` | Middle |
| `Mode.c` | Natural-language units (default) |

### `Morpheme` fields

| Field | Description |
|-------|-------------|
| `surface` | The original text span |
| `dictionaryForm` | Base (dictionary) form |
| `normalizedForm` | Normalized form |
| `readingForm` | Yomi (reading) in katakana |
| `partOfSpeech` | Up to 8 hierarchical POS tags |

## Dictionary

The system dictionary is not included in this package because of its size.

1. Download the full dictionary from the [SudachiDict releases](https://github.com/WorksApplications/SudachiDict/releases) — get the **SudachiDict_full** archive.
2. Extract `system_full.dic` and place it somewhere accessible at runtime (e.g. copied to `applicationSupportDirectory`).
3. Pass the path to `SudachiDictionary.init(dictionaryPath: ...)`.

A ready-to-use `sudachi.json` config is included in the example at [`example/assets/sudachi/sudachi.json`](https://github.com/Flares243/sudachi_dart/blob/main/example/assets/sudachi/sudachi.json). Copy it alongside your dictionary and pass its path to `configPath`. The dictionary path is supplied separately via `dictionaryPath`, so no edits to the config file are needed.

## Running the example

1. Download the **SudachiDict_full** archive from [SudachiDict releases](https://github.com/WorksApplications/SudachiDict/releases).
2. Extract `system_full.dic` and place it at:
   ```
   example/assets/sudachi/system_full.dic
   ```
   The `sudachi.json` config is already in that folder.
3. Run:
   ```sh
   cd example
   flutter run
   ```

The example app copies both files to the app's support directory on first launch, then loads the dictionary from there.

## Project structure

```
src/                   C header + Rust source (sudachi_rs_wrapper)
lib/                   Dart API
hook/build.dart        Builds the Rust library at compile time
ffigen.yaml            Generates Dart FFI bindings from the C header
```

To regenerate the Dart FFI bindings after changing the C header:

```sh
dart run ffigen --config ffigen.yaml
```

## See also

- [sudachi.rs API docs](https://worksapplications.github.io/sudachi.rs/rust/sudachi/) — original Rust library documentation.
- [WorksApplications/sudachi.rs](https://github.com/WorksApplications/sudachi.rs) — Rust library source.
- [WorksApplications/SudachiDict](https://github.com/WorksApplications/SudachiDict) — dictionary releases.

## Credits & License

This Dart package is licensed under the [Apache-2.0](LICENSE) License.

This project wraps and relies on **[sudachi.rs](https://github.com/WorksApplications/sudachi.rs)**, developed by **Works Applications Co., Ltd.**, which is licensed under the Apache License 2.0.