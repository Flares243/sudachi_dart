import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final logger = Logger('')
      ..level = Level.ALL
      ..onRecord.listen((r) => print(r.message));

    final targetOS = input.config.code.targetOS;
    final targetArch = input.config.code.targetArchitecture;

    final rustProjectUri = input.packageRoot.resolve('src/sudachi_rs_wrapper/');
    final rustProjectDir = rustProjectUri.toFilePath();

    final rustTarget = switch ((targetOS, targetArch)) {
      (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
      (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
      (OS.windows, Architecture.x64) => 'x86_64-pc-windows-msvc',
      _ => null,
    };

    logger.info(
      'Building Rust library for $targetOS ($targetArch -> $rustTarget)…',
    );

    final cargoResult = await Process.run('cargo', [
      'build',
      '--release',
      if (rustTarget != null) ...['--target', rustTarget],
    ], workingDirectory: rustProjectDir);

    if (cargoResult.exitCode != 0) {
      logger.severe(cargoResult.stderr.toString());

      throw Exception(
        'cargo build --release failed (exit ${cargoResult.exitCode})',
      );
    }

    final libFileName = switch (targetOS) {
      OS.macOS => 'libsudachi_rs_wrapper.dylib',
      OS.windows => 'sudachi_rs_wrapper.dll',
      _ => throw Exception('Unsupported target OS: $targetOS'),
    };

    final targetDir = rustTarget != null
        ? path.join(rustProjectDir, 'target', rustTarget, 'release')
        : path.join(rustProjectDir, 'target', 'release');

    final libPath = path.join(targetDir, libFileName);

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/${input.packageName}_bindings_generated.dart',
        linkMode: DynamicLoadingBundled(),
        file: Uri.file(libPath),
      ),
    );

    output.dependencies
      ..add(rustProjectUri.resolve('src/lib.rs'))
      ..add(rustProjectUri.resolve('Cargo.toml'))
      ..add(rustProjectUri.resolve('Cargo.lock'));
  });
}
