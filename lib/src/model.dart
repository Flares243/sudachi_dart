/// Tokenization split granularity.
enum Mode {
  /// Short, atomic units (most granular).
  a,

  /// Middle granularity.
  b,

  /// Natural-language / named-entity units (least granular, default).
  c,
}

/// A single morpheme (token) returned by the tokenizer.
class Morpheme {
  final String surface;
  final String dictionaryForm;
  final String normalizedForm;
  final String readingForm;

  /// Six-element POS tuple: four POS levels, conjugation type, and conjugation form.
  final List<String> partOfSpeech;

  const Morpheme({
    required this.surface,
    required this.dictionaryForm,
    required this.normalizedForm,
    required this.readingForm,
    required this.partOfSpeech,
  });

  factory Morpheme.fromJson(Map<String, dynamic> json) => Morpheme(
    surface: json['surface'] as String,
    dictionaryForm: json['dictionary_form'] as String,
    normalizedForm: json['normalized_form'] as String,
    readingForm: json['reading_form'] as String,
    partOfSpeech: List<String>.from(json['part_of_speech'] as List),
  );

  @override
  String toString() =>
      'Morpheme(surface: $surface, dictionaryForm: $dictionaryForm, '
      'normalizedForm: $normalizedForm, readingForm: $readingForm, '
      'pos: ${partOfSpeech.take(2).join('-')})';
}

typedef TokenizeResult = ({List<Morpheme> morphemes, String rawJson});
