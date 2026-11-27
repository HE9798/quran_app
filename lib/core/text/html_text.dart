/// Turns text that arrives with HTML in it (tafsir and translations from
/// Quran.com, some ahadeeth) into plain text with paragraph breaks.
///
/// [dropFootnotes] also removes footnote numbers (`<sup foot_note=..>1</sup>`).
String htmlToText(String html, {bool dropFootnotes = false}) {
  var s = html;
  if (dropFootnotes) s = s.replaceAll(RegExp(r'<sup[^>]*>.*?</sup>', dotAll: true), '');
  s = s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|h[1-6]|li|blockquote)>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
      .replaceAll('&amp;', '&')
      // some texts carry escaped quotes: \" or \'
      .replaceAllMapped(RegExp(r'''\\(["'])'''), (m) => m[1]!);
  s = s
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  return s.trim();
}
