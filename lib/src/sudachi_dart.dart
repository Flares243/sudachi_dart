import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:sudachi_dart/src/model.dart';

import 'sudachi_dart_bindings_generated.dart' as bindings;

/// A loaded Sudachi dictionary.
///
/// Load once with [init], then share across [SudachiTokenizer]s.
/// Call [dispose] when done.
class SudachiDictionary implements Finalizable {
  String? configPath;
  String? resourceDir;
  String? dictionaryPath;

  Pointer<bindings.DictionaryHandle>? _handle;
  bool _disposed = false;

  SudachiDictionary();

  static Future<bool> validateFile(String dictionaryPath) async {
    final result = await Isolate.run(() => _callNativeValidate(dictionaryPath));
    return result;
  }

  /// Loads the dictionary on a background isolate.
  ///
  /// Safe to call from the UI isolate — does not block.
  Future<void> init({
    String? configPath,
    String? resourceDir,
    String? dictionaryPath,
  }) async {
    if (_disposed) {
      throw StateError('Cannot re-initialize a disposed dictionary.');
    }

    // Free any previously-loaded handle before overwriting it.
    final existingHandle = _handle;
    if (existingHandle != null) {
      _dictFinalizer.detach(this);
      bindings.sudachi_free_dictionary(existingHandle);
      _handle = null;
    }

    this.configPath = configPath;
    this.resourceDir = resourceDir;
    this.dictionaryPath = dictionaryPath;

    final address = await Isolate.run(
      () => _callNativeInitDictionary(configPath, resourceDir, dictionaryPath),
    );

    _handle = Pointer.fromAddress(address);
    _dictFinalizer.attach(this, _handle!.cast(), detach: this);
  }

  /// Frees the native dictionary. Do not use this object afterwards.
  void dispose() {
    if (!_disposed) {
      final handle = _handle;
      if (handle != null) {
        _dictFinalizer.detach(this);
        bindings.sudachi_free_dictionary(handle);
      }
      _disposed = true;
    }
  }
}

/// A Japanese tokenizer backed by a [SudachiDictionary].
///
/// Call [dispose] when done.
class SudachiTokenizer implements Finalizable {
  SudachiDictionary? dictionary;

  Pointer<bindings.TokenizerHandle>? _handle;
  bool _disposed = false;

  SudachiTokenizer();

  /// Safe to call from the UI isolate — does not block.
  Future<void> init(SudachiDictionary dictionary) async {
    if (_disposed) {
      throw StateError('Cannot re-initialize a disposed tokenizer.');
    }

    if (dictionary._disposed) {
      throw StateError('Cannot create tokenizer from a disposed dictionary.');
    }

    final dictHandle = dictionary._handle;
    if (dictHandle == null) {
      throw StateError(
        'Dictionary has not been initialized. Call init() first.',
      );
    }

    // Free any previously-created handle before overwriting it.
    final existingHandle = _handle;
    if (existingHandle != null) {
      _tokenizerFinalizer.detach(this);
      bindings.sudachi_free_tokenizer(existingHandle);
      _handle = null;
    }

    this.dictionary = dictionary;

    final dictHandleAddress = dictHandle.address;
    final address = await Isolate.run(
      () => _callNativeInitTokenizer(dictHandleAddress),
    );

    _handle = Pointer.fromAddress(address);
    _tokenizerFinalizer.attach(this, _handle!.cast(), detach: this);
  }

  /// Tokenizes [text] on a background isolate.
  Future<TokenizeResult> tokenize(
    String text, {
    Mode mode = Mode.c,
    bool enableDebug = false,
  }) async {
    if (_disposed) throw StateError('Tokenizer has been disposed.');
    final handle = _handle;

    if (handle == null) {
      throw StateError(
        'Tokenizer has not been initialized. Call init() first.',
      );
    }

    final port = await _helperIsolateSendPort;
    final id = _nextRequestId++;
    final completer = Completer<TokenizeResult>();

    _pendingRequests[id] = completer;
    port.send(_TokenizeRequest(id, handle.address, text, mode, enableDebug));

    return completer.future;
  }

  /// Frees the native tokenizer. Do not use this object afterwards.
  void dispose() {
    if (!_disposed) {
      final handle = _handle;

      if (handle != null) {
        _tokenizerFinalizer.detach(this);
        bindings.sudachi_free_tokenizer(handle);
      }

      _disposed = true;
    }
  }
}

// -- Finalizers (release native memory if dispose() is forgotten) -----------
final _dictFinalizer = NativeFinalizer(
  Native.addressOf<
        NativeFunction<Void Function(Pointer<bindings.DictionaryHandle>)>
      >(bindings.sudachi_free_dictionary)
      .cast(),
);

final _tokenizerFinalizer = NativeFinalizer(
  Native.addressOf<
        NativeFunction<Void Function(Pointer<bindings.TokenizerHandle>)>
      >(bindings.sudachi_free_tokenizer)
      .cast(),
);

// -- Async helper isolate ---------------------------------------------------
class _TokenizeRequest {
  final int id;
  final int handleAddress;
  final String text;
  final Mode mode;
  final bool enableDebug;

  const _TokenizeRequest(
    this.id,
    this.handleAddress,
    this.text,
    this.mode,
    this.enableDebug,
  );
}

class _TokenizeResponse {
  final int id;
  final List<Morpheme>? result;
  final String? rawResult;
  final String? error;

  const _TokenizeResponse(this.id, {this.result, this.rawResult, this.error});
}

int _nextRequestId = 0;
final Map<int, Completer<TokenizeResult>> _pendingRequests = {};

final Future<SendPort> _helperIsolateSendPort = _spawnHelper();

Future<SendPort> _spawnHelper() async {
  final completer = Completer<SendPort>();

  final receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        completer.complete(data);
        return;
      }

      if (data is _TokenizeResponse) {
        final pending = _pendingRequests.remove(data.id);
        if (pending == null) return;

        if (data.error != null) {
          pending.completeError(StateError(data.error!));
        } else {
          pending.complete((
            morphemes: data.result!,
            rawJson: data.rawResult ?? '',
          ));
        }

        return;
      }

      throw UnsupportedError('Unexpected message type: ${data.runtimeType}');
    });

  await Isolate.spawn((SendPort sendPort) {
    final helperPort = ReceivePort()
      ..listen((dynamic data) {
        if (data is _TokenizeRequest) {
          try {
            final result = _callNativeTokenize(
              data.handleAddress,
              data.text,
              data.mode,
              data.enableDebug,
            );

            sendPort.send(
              _TokenizeResponse(
                data.id,
                result: result.morphemes,
                rawResult: result.rawJson,
              ),
            );
          } catch (e) {
            sendPort.send(_TokenizeResponse(data.id, error: e.toString()));
          }
          return;
        }
        throw UnsupportedError('Unexpected message type: ${data.runtimeType}');
      });
    sendPort.send(helperPort.sendPort);
  }, receivePort.sendPort);

  return completer.future;
}

// -- Native helpers (isolate-safe) ------------------------------------------
bool _callNativeValidate(String dictionaryPath) {
  final dictionaryPathPtr = dictionaryPath.toNativeUtf8();
  try {
    final handle = bindings.sudachi_is_valid_dictionary(
      dictionaryPathPtr.cast(),
    );

    return handle;
  } finally {
    malloc.free(dictionaryPathPtr);
  }
}

int _callNativeInitDictionary(
  String? configPath,
  String? resourceDir,
  String? dictionaryPath,
) {
  final configPathPtr = configPath?.toNativeUtf8() ?? nullptr;
  final resourceDirPtr = resourceDir?.toNativeUtf8() ?? nullptr;
  final dictionaryPathPtr = dictionaryPath?.toNativeUtf8() ?? nullptr;

  try {
    final handle = bindings.sudachi_init_dictionary(
      configPathPtr.cast(),
      resourceDirPtr.cast(),
      dictionaryPathPtr.cast(),
    );

    if (handle == nullptr) {
      throw StateError(
        'Failed to initialize Sudachi dictionary from: $dictionaryPath',
      );
    }

    return handle.address;
  } finally {
    malloc.free(configPathPtr);
    malloc.free(resourceDirPtr);
    malloc.free(dictionaryPathPtr);
  }
}

int _callNativeInitTokenizer(int dictionaryHandleAddress) {
  final dictHandle = Pointer<bindings.DictionaryHandle>.fromAddress(
    dictionaryHandleAddress,
  );
  final handle = bindings.sudachi_init_tokenizer(dictHandle);
  if (handle == nullptr) {
    throw StateError('Failed to initialize Sudachi tokenizer.');
  }
  return handle.address;
}

TokenizeResult _callNativeTokenize(
  int handleAddress,
  String text,
  Mode mode,
  bool enableDebug,
) {
  final handle = Pointer<bindings.TokenizerHandle>.fromAddress(handleAddress);
  final textPtr = text.toNativeUtf8();
  try {
    final resultPtr = bindings.sudachi_tokenize(
      handle,
      textPtr.cast(),
      mode.index,
      enableDebug ? 1 : 0,
    );
    if (resultPtr == nullptr) {
      throw StateError('Tokenization failed — native function returned null.');
    }
    try {
      final jsonStr = resultPtr.cast<Utf8>().toDartString();
      final decoded = jsonDecode(jsonStr) as List<dynamic>;

      return (
        morphemes: decoded
            .cast<Map<String, dynamic>>()
            .map(Morpheme.fromJson)
            .toList(),
        rawJson: jsonStr,
      );
    } finally {
      bindings.sudachi_free_string(resultPtr);
    }
  } finally {
    malloc.free(textPtr);
  }
}
