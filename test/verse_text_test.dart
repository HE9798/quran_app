import 'package:flutter_test/flutter_test.dart';
import 'package:quran/features/quran/data/verse_text_repository.dart';

void main() {
  final clean = VerseTextRepository.htmlToText;

  test('tafsir HTML becomes paragraphs of plain text', () {
    const html = '<p><span class="arabic qpc-hafs">( ذلك الكتاب )</span></p>'
        '<p lang="ar" class="ar ">قال ابن عباس :<span class="blue"> هذا الكتاب</span> .</p>';
    expect(clean(html), '( ذلك الكتاب )\n\nقال ابن عباس : هذا الكتاب .');
  });

  test('translation footnote numbers are removed', () {
    const html = 'In the name of Allāh,<sup foot_note=195932>1</sup> the Entirely Merciful.'
        '<sup foot_note=195931>2</sup>';
    expect(clean(html, dropFootnotes: true), 'In the name of Allāh, the Entirely Merciful.');
  });

  test('HTML entities and line breaks are turned into text', () {
    expect(clean('Ka`b &amp; Ubayy said &quot;O Muhammad!&quot;<br/>Next&#39;s line'),
        'Ka`b & Ubayy said "O Muhammad!"\nNext\'s line');
  });

  test('escaped quotes lose their backslash', () {
    expect(clean(r'وأتى بـ \"على\" في هذا'), 'وأتى بـ "على" في هذا');
  });

  test('extra blank lines and spaces are squeezed', () {
    expect(clean('<h2>Title</h2><p></p><p>  a   b  </p>'), 'Title\n\na b');
  });
}
