import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sudachi_dart/sudachi_dart.dart';
import 'package:path/path.dart' as path;

Future<({String dictFile, String jsonFile})>
_extractDictionaryIfNeeded() async {
  final appDir = await getApplicationSupportDirectory();
  final sudachiDir = Directory(path.join(appDir.path, 'sudachi'));
  sudachiDir.createSync(recursive: true);

  final sudachiJsonFile = File(
    path.join(appDir.path, 'sudachi', 'sudachi.json'),
  );

  if (!sudachiJsonFile.existsSync()) {
    final bytes = await rootBundle.load('assets/sudachi/sudachi.json');
    await sudachiJsonFile.writeAsBytes(bytes.buffer.asUint8List());
  }

  final dictionaryDir = Directory(
    path.join(appDir.path, 'sudachi', 'dictionary'),
  );
  await dictionaryDir.create(recursive: true);

  final dicFile = File(path.join(dictionaryDir.path, 'system_full.dic'));

  if (!dicFile.existsSync()) {
    final bytes = await rootBundle.load('assets/sudachi/system_full.dic');
    await dicFile.writeAsBytes(bytes.buffer.asUint8List());
  }

  return (dictFile: dicFile.path, jsonFile: sudachiJsonFile.path);
}

void main() {
  runApp(const SudachiApp());
}

class SudachiApp extends StatelessWidget {
  const SudachiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudachi Dart Demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const TokenizerPage(),
    );
  }
}

class TokenizerPage extends StatefulWidget {
  const TokenizerPage({super.key});

  @override
  State<TokenizerPage> createState() => _TokenizerPageState();
}

class _TokenizerPageState extends State<TokenizerPage> {
  SudachiDictionary? _dictionary;
  SudachiTokenizer? _tokenizer;

  final _textController = TextEditingController(text: '私は東京大学で日本語を勉強しています。');

  Mode _selectedMode = Mode.c;
  List<Morpheme> _morphemes = [];
  String? _error;
  bool _initializing = false;
  bool _tokenizing = false;

  @override
  void initState() {
    super.initState();
    _initDictionary();
  }

  Future<void> _initDictionary() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    try {
      final paths = await _extractDictionaryIfNeeded();
      final dict = await SudachiDictionary.init(
        dictionaryPath: paths.dictFile,
        configPath: paths.jsonFile,
      );
      final tok = await SudachiTokenizer.init(dict);
      setState(() {
        _dictionary = dict;
        _tokenizer = tok;
      });
    } catch (e) {
      setState(() => _error = 'Init failed: $e');
    } finally {
      setState(() => _initializing = false);
    }
  }

  Future<void> _tokenize() async {
    final tokenizer = _tokenizer;
    if (tokenizer == null) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _tokenizing = true;
      _error = null;
    });
    try {
      final morphemes = await tokenizer.tokenize(text, mode: _selectedMode);
      setState(() => _morphemes = morphemes);
    } catch (e) {
      setState(() => _error = 'Tokenization failed: $e');
    } finally {
      setState(() => _tokenizing = false);
    }
  }

  @override
  void dispose() {
    _dictionary?.dispose();
    _tokenizer?.dispose();

    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sudachi Dart Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_initializing)
              const LinearProgressIndicator()
            else if (_dictionary == null)
              FilledButton(
                onPressed: _initDictionary,
                child: const Text('Load Dictionary'),
              )
            else
              const Text(
                'Dictionary loaded',
                style: TextStyle(color: Colors.green),
              ),
            const SizedBox(height: 16),

            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Japanese text',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Text('Mode: '),
                const SizedBox(width: 8),
                for (final mode in Mode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(mode.name.toUpperCase()),
                      selected: _selectedMode == mode,
                      onSelected: (_) => setState(() => _selectedMode = mode),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: (_tokenizer != null && !_tokenizing)
                      ? _tokenize
                      : null,
                  child: _tokenizing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tokenize'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_error != null)
              SelectableText(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),

            const Divider(),

            Expanded(
              child: _morphemes.isEmpty
                  ? const Center(child: Text('Results will appear here'))
                  : ListView.builder(
                      itemCount: _morphemes.length,
                      itemBuilder: (context, i) {
                        final m = _morphemes[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.surface,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                _InfoRow('dictionary', m.dictionaryForm),
                                _InfoRow('normalized', m.normalizedForm),
                                _InfoRow('reading', m.readingForm),
                                _InfoRow('pos', m.partOfSpeech.join(' / ')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}
