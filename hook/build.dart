import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';

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
    final packageRoot = input.packageRoot.toFilePath();
    final sep = Platform.pathSeparator;
    final rustProjectDir = '${packageRoot}src${sep}sudachi_rs_wrapper';

    final rustTarget = _getRustTargetTriple(targetOS, targetArch);

    logger.info(
      'Building Rust library for $targetOS ($targetArch -> $rustTarget)…',
    );

    final cargoArgs = [
      'build',
      '--release',
      if (rustTarget != null) ...['--target', rustTarget],
    ];

    final cargoResult = await Process.run(
      'cargo',
      cargoArgs,
      workingDirectory: rustProjectDir,
    );

    if (cargoResult.exitCode != 0) {
      logger.severe(cargoResult.stderr.toString());
      throw Exception(
        'cargo build --release failed (exit ${cargoResult.exitCode})',
      );
    }

    final libFileName = switch (targetOS) {
      OS.macOS => 'libsudachi_rs_wrapper.dylib',
      OS.windows => 'sudachi_rs_wrapper.dll',
      OS.linux => 'libsudachi_rs_wrapper.so',
      _ => throw Exception('Unsupported target OS: $targetOS'),
    };

    final targetDir = rustTarget != null
        ? '$rustProjectDir${sep}target$sep$rustTarget${sep}release'
        : '$rustProjectDir${sep}target${sep}release';

    final libPath = '$targetDir$sep$libFileName';

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: '${input.packageName}_bindings_generated.dart',
        linkMode: DynamicLoadingBundled(),
        file: Uri.file(libPath),
      ),
    );

    output.dependencies
      ..add(Uri.file('$rustProjectDir${sep}src${sep}lib.rs'))
      ..add(Uri.file('$rustProjectDir${sep}Cargo.toml'))
      ..add(Uri.file('$rustProjectDir${sep}Cargo.lock'));
  });
}

String? _getRustTargetTriple(OS os, Architecture arch) {
  return switch ((os, arch)) {
    (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
    (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
    (OS.linux, Architecture.x64) => 'x86_64-unknown-linux-gnu',
    (OS.linux, Architecture.arm64) => 'aarch64-unknown-linux-gnu',
    (OS.windows, Architecture.x64) => 'x86_64-pc-windows-msvc',
    _ => null,
  };
}
