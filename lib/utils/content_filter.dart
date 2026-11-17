/// Basic objectionable-language filter applied to user-generated text
/// (post captions and comments) before submission.
///
/// Matches whole words only (after normalizing common character
/// substitutions) so ordinary words that contain a banned sequence
/// are not rejected.
class ContentFilter {
  static const List<String> _bannedWords = [
    'fuck', 'fvck', 'fucking', 'fucker', 'motherfucker',
    'shit', 'bullshit',
    'bitch', 'bitches',
    'asshole',
    'cunt',
    'dick', 'dickhead',
    'pussy',
    'whore', 'whores', 'slut', 'sluts', 'slvt', 'hoes',
    'faggot', 'fag',
    'nigger', 'nigga',
    'retard', 'retarded',
    'kike', 'spic', 'chink', 'wetback',
    'rape', 'rapist',
    'porn', 'porno', 'pornhub', 'onlyfans', 'nsfw', 'blowjob', 'handjob',
    'cum', 'cumming', 'cock', 'cocks', 'tits', 'titties', 'boobs',
  ];

  /// Explicit phrases or markers blocked anywhere in profile text/captions.
  static final RegExp _phrasePattern = RegExp(
    r'(🔞|18\+|\+18|\+only|busting\s*nuts|nasty\s*hoes|nasty\s*sluts)',
    caseSensitive: false,
  );

  /// Substring patterns blocked inside usernames (where words are concatenated
  /// without spaces, e.g. "ilovenastysluts1k").
  static const List<String> _bannedUsernameSubstrings = [
    'fuck',
    'fvck',
    'fuk',
    'shit',
    'bitch',
    'asshole',
    'cunt',
    'dickhead',
    'pussy',
    'whore',
    'slut',
    'slvt',
    'hoes',
    'nastyhoe',
    'nastyslut',
    'bustingnut',
    'faggot',
    'nigger',
    'nigga',
    'retard',
    'kike',
    'spic',
    'chink',
    'wetback',
    'rapist',
    'porn',
    'onlyfans',
    'nsfw',
    'blowjob',
    'handjob',
  ];

  static final RegExp _pattern = RegExp(
    r'\b(' + _bannedWords.join('|') + r')\b',
    caseSensitive: false,
  );

  static final RegExp _usernamePattern = RegExp(
    '(' + _bannedUsernameSubstrings.join('|') + ')',
    caseSensitive: false,
  );

  /// Normalize common character substitutions used to evade filters.
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('@', 'a')
        .replaceAll('4', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('!', 'i');
  }

  /// Returns true if [text] contains objectionable language.
  static bool containsObjectionableContent(String text) {
    if (text.trim().isEmpty) return false;
    final lower = text.toLowerCase();
    return _phrasePattern.hasMatch(lower) ||
        _pattern.hasMatch(_normalize(lower));
  }

  /// Returns true if a [username] contains objectionable substrings
  /// (handles concatenated words without word boundaries).
  static bool containsObjectionableUsername(String username) {
    if (username.trim().isEmpty) return false;
    final raw = username.toLowerCase().trim();
    return _usernamePattern.hasMatch(raw) ||
        _usernamePattern.hasMatch(_normalize(raw));
  }
}
