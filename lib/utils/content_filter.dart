/// Basic objectionable-language filter applied to user-generated text
/// (post captions and comments) before submission.
///
/// Matches whole words only (after normalizing common character
/// substitutions) so ordinary words that contain a banned sequence
/// are not rejected.
class ContentFilter {
  static const List<String> _bannedWords = [
    'fuck', 'fucking', 'fucker', 'motherfucker',
    'shit', 'bullshit',
    'bitch', 'bitches',
    'asshole',
    'cunt',
    'dick', 'dickhead',
    'pussy',
    'whore', 'slut',
    'faggot', 'fag',
    'nigger', 'nigga',
    'retard', 'retarded',
    'kike', 'spic', 'chink', 'wetback',
    'rape', 'rapist',
  ];

  static final RegExp _pattern = RegExp(
    r'\b(' + _bannedWords.join('|') + r')\b',
    caseSensitive: false,
  );

  /// Normalize common character substitutions used to evade filters.
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('!', 'i');
  }

  /// Returns true if [text] contains objectionable language.
  static bool containsObjectionableContent(String text) {
    if (text.trim().isEmpty) return false;
    return _pattern.hasMatch(_normalize(text));
  }
}
