# Builds assets/dua/duas.json for the Dua page (two tabs).
#
# How the lists were made: every Quran verse with a supplication pattern
# (ربنا / رب + request / اللهم / سبحانك / لا إله إلا أنت / أعوذ, about 170
# verses) and every narration in the two Sahihs with اللهم / ربنا / أعوذ
# (about 470 groups) was read by hand. Kept: supplications a Muslim can make.
# Left out: words of disbelievers and of the people of Hell, curses against
# named people, duas for one named person (e.g. "O Allah, give him
# understanding of the religion" for Ibn Abbas), the Badr pleas, stories of
# earlier nations, and "ربنا" used outside a dua. Repeats are merged.
#
#  - Quran: each dua is cut from the verse text of the Tanzil "quran-simple"
#    edition, and its English from Sahih International, both as served by
#    api.alquran.cloud (the Quran API the app already uses). A dua usually
#    starts inside a verse ("... who say: Our Lord ..."), so each entry gives
#    the words it starts with, in Arabic and in English.
#  - Hadith: each dua is cut word for word from Sahih al-Bukhari / Sahih
#    Muslim (fawazahmed0/hadith-api: ara-bukhari, ara-muslim). Each entry
#    gives its first and last words; the hadith number is read from the data
#    (Bukhari: hadithnumber, Muslim: arabicnumber = Abdul-Baqi numbering) and
#    must equal the number written here. The English is our own.
#
# The script stops if any text or number can't be found.
#
# Usage:
#   python build_duas.py <folder with quran-simple.json, en-sahih.json,
#                         ara-bukhari.json, ara-muslim.json> <out json>
# quran-simple.json = https://api.alquran.cloud/v1/quran/quran-simple
# en-sahih.json     = https://api.alquran.cloud/v1/quran/en.sahih
# ara-*.json        = https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-<book>.json
import json, re, sys

D, OUT = sys.argv[1], sys.argv[2]
load = lambda n: json.load(open(f'{D}/{n}', encoding='utf-8'))

HARAKAT = re.compile(r'[ً-ْٰـۖ-ۭ]')
# matching also skips punctuation: the hadith texts put commas between phrases
STRIP = re.compile(r'[ً-ْٰـ‏‎ۖ-ۭ،؛,"]')

# Topics (the chips on the page). Both tabs use the same keys.
TOPICS = ['forgiveness', 'guidance', 'protection', 'hardship', 'family',
          'goodness', 'praise', 'occasions']


def norm_map(s):
    """Text without harakat (one alef form, one yaa form) and where each kept
    character came from in the original."""
    out, idx = [], []
    for i, ch in enumerate(s):
        if STRIP.match(ch):
            continue
        out.append('ا' if ch in 'إأآٱ' else 'ي' if ch == 'ى' else ch)
        idx.append(i)
    return ''.join(out), idx


def norm(s):
    return norm_map(s)[0]


def cut(text, start, end=None):
    """The part of [text] from the words [start] to the words [end] (or to the
    end), with its harakat. None if not found."""
    n, idx = norm_map(text)
    a = 0 if start is None else n.find(norm(start))
    if a < 0:
        return None
    if end is None:
        return text[idx[a]:].strip()
    b = n.find(norm(end), a)
    if b < 0:
        return None
    last = idx[b + len(norm(end)) - 1]
    # keep the harakat of the last letter
    while last + 1 < len(text) and HARAKAT.match(text[last + 1]):
        last += 1
    return text[idx[a]:last + 1].strip()


# ------------------------------------------------------------------ Quran
QS = load('quran-simple.json')['data']['surahs']
EN = load('en-sahih.json')['data']['surahs']

# (surah, first ayah, last ayah, Arabic start words or None = whole verse,
#  English start words or None, topic)
QURAN = [
    (1, 6, 7, None, None, 'guidance'),
    (2, 32, 32, 'سبحانك لا علم', 'Exalted are You', 'praise'),
    (2, 126, 126, 'رب اجعل', 'My Lord', 'goodness'),
    (2, 127, 127, 'ربنا تقبل', 'Our Lord', 'goodness'),
    (2, 128, 128, None, None, 'guidance'),
    (2, 201, 201, 'ربنا آتنا', 'Our Lord', 'goodness'),
    (2, 250, 250, 'ربنا أفرغ', 'Our Lord', 'hardship'),
    (2, 285, 285, 'سمعنا وأطعنا', 'We hear', 'forgiveness'),
    (2, 286, 286, 'ربنا لا تؤاخذنا', 'Our Lord', 'forgiveness'),
    (3, 8, 8, None, 'Our Lord', 'guidance'),
    (3, 9, 9, None, 'Our Lord', 'praise'),
    (3, 16, 16, 'ربنا إننا', 'Our Lord', 'forgiveness'),
    (3, 26, 27, 'اللهم مالك', 'O Allah', 'praise'),
    (3, 35, 35, 'رب إني نذرت', 'My Lord', 'family'),
    (3, 38, 38, 'رب هب لي', 'My Lord', 'family'),
    (3, 53, 53, None, None, 'guidance'),
    (3, 147, 147, 'ربنا اغفر لنا', 'Our Lord', 'forgiveness'),
    (3, 173, 173, 'حسبنا الله', 'Sufficient for us', 'hardship'),
    (3, 191, 194, 'ربنا ما خلقت', 'Our Lord', 'protection'),
    (4, 75, 75, 'ربنا أخرجنا', 'Our Lord', 'hardship'),
    (5, 83, 83, 'ربنا آمنا', 'Our Lord', 'guidance'),
    (7, 23, 23, 'ربنا ظلمنا', 'Our Lord', 'forgiveness'),
    (7, 47, 47, 'ربنا لا تجعلنا', 'Our Lord', 'protection'),
    (7, 89, 89, 'ربنا افتح', 'Our Lord, decide', 'hardship'),
    (7, 126, 126, 'ربنا أفرغ', 'Our Lord', 'hardship'),
    (7, 143, 143, 'سبحانك تبت', 'Exalted are You', 'forgiveness'),
    (7, 151, 151, 'رب اغفر', 'My Lord', 'forgiveness'),
    (7, 155, 156, 'أنت ولينا', 'You are our', 'forgiveness'),
    (9, 129, 129, 'حسبي الله', 'Sufficient for me', 'praise'),
    (10, 85, 86, 'على الله توكلنا', 'Upon Allah', 'protection'),
    (11, 47, 47, 'رب إني أعوذ', 'My Lord', 'forgiveness'),
    (12, 101, 101, None, None, 'guidance'),
    (14, 35, 35, 'رب اجعل', 'My Lord', 'protection'),
    (14, 40, 41, None, None, 'family'),
    (17, 24, 24, 'رب ارحمهما', 'My Lord', 'family'),
    (17, 80, 80, 'رب أدخلني', 'My Lord', 'guidance'),
    (18, 10, 10, 'ربنا آتنا', 'Our Lord', 'guidance'),
    (19, 4, 6, 'رب إني وهن', 'My Lord', 'family'),
    (20, 25, 28, 'رب اشرح', 'My Lord', 'guidance'),
    (20, 114, 114, 'رب زدني', 'My Lord', 'guidance'),
    (21, 83, 83, 'أني مسني', 'Indeed, adversity', 'hardship'),
    (21, 87, 87, 'لا إله إلا أنت', 'There is no deity', 'hardship'),
    (21, 89, 89, 'رب لا تذرني', 'My Lord', 'family'),
    (21, 112, 112, 'رب احكم', 'My Lord', 'hardship'),
    (23, 26, 26, 'رب انصرني', 'My Lord', 'hardship'),
    (23, 29, 29, 'رب أنزلني', 'My Lord', 'goodness'),
    (23, 93, 94, 'رب إما تريني', 'My Lord', 'protection'),
    (23, 97, 98, 'رب أعوذ', 'My Lord', 'protection'),
    (23, 109, 109, 'ربنا آمنا', 'Our Lord', 'forgiveness'),
    (23, 118, 118, 'رب اغفر', 'My Lord', 'forgiveness'),
    (25, 65, 66, 'ربنا اصرف', 'Our Lord', 'protection'),
    (25, 74, 74, 'ربنا هب لنا', 'Our Lord', 'family'),
    (26, 83, 85, None, 'My Lord', 'goodness'),
    (26, 169, 169, None, 'My Lord', 'protection'),
    (27, 19, 19, 'رب أوزعني', 'My Lord', 'guidance'),
    (27, 44, 44, 'رب إني ظلمت', 'My Lord', 'forgiveness'),
    (28, 16, 16, 'رب إني ظلمت', 'My Lord', 'forgiveness'),
    (28, 17, 17, 'رب بما أنعمت', 'My Lord', 'guidance'),
    (28, 21, 21, 'رب نجني', 'My Lord', 'protection'),
    (28, 24, 24, 'رب إني لما', 'My Lord', 'goodness'),
    (29, 30, 30, 'رب انصرني', 'My Lord', 'hardship'),
    (37, 100, 100, None, 'My Lord', 'family'),
    (39, 46, 46, 'اللهم فاطر', 'O Allah', 'praise'),
    (40, 7, 9, 'ربنا وسعت', 'Our Lord', 'forgiveness'),
    (40, 44, 44, 'أفوض أمري', 'I entrust', 'praise'),
    (43, 13, 14, 'سبحان الذي سخر', 'Exalted is He', 'occasions'),
    (46, 15, 15, 'رب أوزعني', 'My Lord', 'family'),
    (54, 10, 10, 'أني مغلوب', 'Indeed, I am overpowered', 'hardship'),
    (59, 10, 10, 'ربنا اغفر لنا', 'Our Lord', 'forgiveness'),
    (60, 4, 5, 'ربنا عليك توكلنا', 'Our Lord, upon You', 'praise'),
    (66, 8, 8, 'ربنا أتمم', 'Our Lord', 'forgiveness'),
    (66, 11, 11, 'رب ابن', 'My Lord', 'goodness'),
    (71, 28, 28, None, None, 'forgiveness'),
]

# Where the dua ends before the verse does: (surah, ayah) -> (Arabic end
# words, English end words).
QURAN_END = {
    (2, 126): ('واليوم الآخر', 'the Last Day'),     # then "[Allah] said: and whoever disbelieves"
    (7, 156): ('هدنا إليك', 'turned back to You'),  # then Allah's answer
    (28, 16): ('فاغفر لي', 'so forgive me'),        # then "and He forgave him"
}


def clean_en(s):
    # the dua is quoted inside the verse: drop its double quotes and a
    # closing single quote
    s = re.sub(r'["“”]', '', s).strip()
    while s and s[-1] in "'’":
        s = s[:-1].rstrip()
    if s.endswith(',') or s.endswith('?'):  # 4:75 is phrased as a question
        s = s[:-1] + '.'
    return s


def arabic_digits(n):
    return ''.join('٠١٢٣٤٥٦٧٨٩'[int(c)] for c in str(n))


def ayah_text(surah, ayah):
    ar = QS[surah - 1]['ayahs'][ayah - 1]
    en = EN[surah - 1]['ayahs'][ayah - 1]
    assert ar['numberInSurah'] == ayah and en['numberInSurah'] == ayah
    text = ar['text'].replace('۞', '').strip()  # the hizb-quarter mark
    if ayah == 1 and surah not in (1, 9):  # quran-simple puts the basmala in ayah 1
        text = text.replace('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ', '')
    return text, en['text']


quran = []
for surah, first, last, ar_start, en_start, topic in QURAN:
    assert topic in TOPICS, topic
    ar_parts, en_parts = [], []
    for ayah in range(first, last + 1):
        ar, en = ayah_text(surah, ayah)
        if ayah == first and ar_start:
            got = cut(ar, ar_start)
            assert got, f'Quran {surah}:{ayah}: Arabic start "{ar_start}" not found'
            ar = got
        if ayah == first and en_start:
            i = en.find(en_start)
            assert i >= 0, f'Quran {surah}:{ayah}: English start "{en_start}" not found in: {en}'
            en = en[i:]
        if (surah, ayah) in QURAN_END:
            ar_end, en_end = QURAN_END[(surah, ayah)]
            got = cut(ar, None, ar_end)
            j = en.find(en_end)
            assert got and j >= 0, f'Quran {surah}:{ayah}: end words not found in: {en}'
            ar, en = got, en[:j + len(en_end)] + '.'
        ar_parts.append(f'{ar} ﴿{arabic_digits(ayah)}﴾' if last > first else ar)
        en_parts.append(clean_en(en))
    name = norm(QS[surah - 1]['name']).replace('سورة ', '').strip()
    quran.append({
        'ar': ' '.join(ar_parts),
        'en': ' '.join(en_parts),
        'surah': surah,
        'from': first,
        'to': last,
        'surahAr': name,
        'surahEn': QS[surah - 1]['englishName'],
        'topic': topic,
    })

# ----------------------------------------------------------------- Hadith
BOOKS = {
    'bukhari': load('ara-bukhari.json')['hadiths'],
    'muslim': load('ara-muslim.json')['hadiths'],
}


def number(book, h):
    if book == 'bukhari':
        return int(h['hadithnumber'])
    v = h.get('arabicnumber')
    return int(float(v)) if v not in (None, '') else None


B, M = 'bukhari', 'muslim'

# (book, number, first words, last words, topic, title Ar, title En, English)
HADITH = [
    # ---- forgiveness
    (B, 6306, 'اللهم أنت ربي لا إله إلا أنت خلقتني', 'لا يغفر الذنوب إلا أنت', 'forgiveness',
     'سيد الاستغفار', 'The master of seeking forgiveness',
     'O Allah, You are my Lord; there is no god but You. You created me and I am Your servant, '
     'and I hold to Your covenant and promise as much as I can. I seek refuge in You from the evil '
     'of what I have done. I acknowledge Your favour upon me, and I acknowledge my sin, so forgive '
     'me, for none forgives sins but You.'),
    (B, 834, 'اللهم إني ظلمت نفسي ظلما كثيرا', 'إنك أنت الغفور الرحيم', 'forgiveness',
     'علّمه النبي ﷺ أبا بكر', 'Taught to Abu Bakr',
     'O Allah, I have wronged myself greatly, and none forgives sins but You. So forgive me with '
     'forgiveness from You, and have mercy on me. You are the Forgiving, the Merciful.'),
    (M, 2719, 'اللهم اغفر لي خطيئتي وجهلي', 'وأنت على كل شيء قدير', 'forgiveness', '', '',
     'O Allah, forgive me my mistakes, my ignorance, my excess in my affairs, and what You know '
     'better than I. O Allah, forgive me what I did in earnest and in jest, by error and on '
     'purpose, and all of that is in me. O Allah, forgive me what I have done and what I will do, '
     'what I did in secret and what I did openly, and what You know better than I. You bring '
     'forward and You put back, and You have power over all things.'),
    (M, 483, 'اللهم اغفر لي ذنبي كله', 'وعلانيته وسره', 'forgiveness',
     'في السجود', 'In prostration',
     'O Allah, forgive me all my sins, the small and the great, the first and the last, the open '
     'and the secret.'),
    (B, 794, 'سبحانك اللهم ربنا وبحمدك', 'اللهم اغفر لي', 'forgiveness',
     'في الركوع والسجود', 'In bowing and prostration',
     'Glory be to You, O Allah, our Lord, and praise be to You. O Allah, forgive me.'),
    (B, 744, 'اللهم باعد بيني وبين خطاياي', 'بالماء والثلج والبرد', 'forgiveness',
     'دعاء الاستفتاح', 'Opening the prayer',
     'O Allah, put a distance between me and my sins as You have put a distance between the east '
     'and the west. O Allah, cleanse me of sins as a white garment is cleansed of dirt. O Allah, '
     'wash away my sins with water, snow and hail.'),
    (M, 476, 'اللهم لك الحمد ملء السماء', 'من الوسخ', 'forgiveness', '', '',
     'O Allah, to You belongs the praise, filling the heavens, filling the earth and filling '
     'whatever You will besides. O Allah, purify me with snow, hail and cold water. O Allah, '
     'purify me of sins and mistakes as a white garment is purified of dirt.'),
    (M, 771, 'اللهم أنت الملك لا إله إلا أنت', 'أستغفرك وأتوب إليك', 'forgiveness',
     'من دعاء الاستفتاح', 'Opening the prayer',
     'O Allah, You are the King; there is no god but You. You are my Lord and I am Your servant. '
     'I have wronged myself and I admit my sin, so forgive me all my sins, for none forgives sins '
     'but You. Guide me to the best of character, for none guides to the best of it but You, and '
     'turn away from me its bad, for none turns away its bad but You. Here I am, at Your service; '
     'all good is in Your hands and evil is not attributed to You. I am by You and to You; blessed '
     'and exalted are You. I seek Your forgiveness and I turn to You in repentance.'),
    (M, 2697, 'اللهم اغفر لي وارحمني واهدني', 'وارزقني', 'forgiveness', '', '',
     'O Allah, forgive me, have mercy on me, guide me and provide for me.'),

    # ---- guidance and religion
    (M, 2720, 'اللهم أصلح لي ديني', 'من كل شر', 'guidance', '', '',
     'O Allah, set right for me my religion, which is the safeguard of my affairs; set right for me '
     'my world, in which is my living; set right for me my Hereafter, to which is my return. Make '
     'life an increase for me in every good, and make death a rest for me from every evil.'),
    (M, 2721, 'اللهم إني أسألك الهدى', 'والعفاف والغنى', 'guidance', '', '',
     'O Allah, I ask You for guidance, piety, chastity and sufficiency.'),
    (M, 2654, 'اللهم مصرف القلوب', 'على طاعتك', 'guidance', '', '',
     'O Allah, Turner of the hearts, turn our hearts to Your obedience.'),
    (M, 2725, 'اللهم اهدني وسددني', 'وسددني', 'guidance', '', '',
     'O Allah, guide me and keep me on the right course.'),
    (M, 2717, 'اللهم لك أسلمت', 'والإنس يموتون', 'guidance', '', '',
     'O Allah, to You I have submitted, in You I believe, in You I trust, to You I turn, and by '
     'You I argue. O Allah, I seek refuge in Your might, there is no god but You, from Your letting '
     'me go astray. You are the Ever-Living who does not die, while jinn and men die.'),
    (M, 770, 'اللهم رب جبرائيل', 'إلى صراط مستقيم', 'guidance',
     'في قيام الليل', 'Opening the night prayer',
     'O Allah, Lord of Jibril, Mika\'il and Israfil, Creator of the heavens and the earth, Knower '
     'of the unseen and the seen, You judge between Your servants in what they differed over. '
     'Guide me, by Your leave, to the truth in what they differed over; You guide whom You will to '
     'a straight path.'),
    (B, 6316, 'اللهم اجعل في قلبي نورا', 'واجعل لي نورا', 'guidance', '', '',
     'O Allah, place light in my heart, light in my sight and light in my hearing; light on my '
     'right, light on my left, light above me, light below me, light in front of me and light '
     'behind me; and make for me light.'),
    (B, 6382, 'اللهم إني أستخيرك بعلمك', 'ثم رضني به', 'guidance',
     'دعاء الاستخارة', 'Istikhara: asking Allah to choose',
     'O Allah, I ask You to choose for me by Your knowledge, I ask You to enable me by Your power, '
     'and I ask You of Your great bounty, for You are able and I am not, You know and I do not, '
     'and You are the Knower of the unseen. O Allah, if You know that this matter is good for me '
     'in my religion, my living and the outcome of my affairs, then decree it for me. And if You '
     'know that it is bad for me in my religion, my living and the outcome of my affairs, then '
     'turn it away from me and turn me away from it, and decree for me the good wherever it is, '
     'then make me pleased with it. (Then name your need.)'),

    # ---- protection and refuge
    (B, 6369, 'اللهم إني أعوذ بك من الهم والحزن', 'وغلبة الرجال', 'protection', '', '',
     'O Allah, I seek refuge in You from worry and grief, from helplessness and laziness, from '
     'cowardice and miserliness, and from being overwhelmed by debt and overpowered by men.'),
    (B, 832, 'اللهم إني أعوذ بك من عذاب القبر', 'من المأثم والمغرم', 'protection',
     'قبل السلام من الصلاة', 'Before ending the prayer',
     'O Allah, I seek refuge in You from the punishment of the grave, I seek refuge in You from the '
     'trial of the False Messiah, and I seek refuge in You from the trials of life and death. O '
     'Allah, I seek refuge in You from sin and from debt.'),
    (B, 6368, 'اللهم إني أعوذ بك من الكسل والهرم', 'بين المشرق والمغرب', 'protection', '', '',
     'O Allah, I seek refuge in You from laziness, old age, sin and debt; from the trial of the '
     'grave and the punishment of the grave; from the trial of the Fire and the punishment of the '
     'Fire; from the evil of the trial of wealth; and I seek refuge in You from the trial of '
     'poverty, and from the trial of the False Messiah. O Allah, wash away my sins with snow and '
     'hail water, cleanse my heart of sins as You cleanse a white garment of dirt, and put a '
     'distance between me and my sins as You have put a distance between the east and the west.'),
    (B, 6365, 'اللهم إني أعوذ بك من البخل', 'من عذاب القبر', 'protection', '', '',
     'O Allah, I seek refuge in You from miserliness, I seek refuge in You from cowardice, I seek '
     'refuge in You from being returned to the worst of old age, I seek refuge in You from the '
     'trial of this world, and I seek refuge in You from the punishment of the grave.'),
    (M, 2722, 'اللهم إني أعوذ بك من العجز والكسل', 'ومن دعوة لا يستجاب لها', 'protection', '', '',
     'O Allah, I seek refuge in You from helplessness and laziness, cowardice, miserliness, old age '
     'and the punishment of the grave. O Allah, give my soul its piety and purify it, You are the '
     'best to purify it; You are its Guardian and its Master. O Allah, I seek refuge in You from '
     'knowledge that does not benefit, from a heart that does not humble itself, from a soul that '
     'is never satisfied, and from a dua that is not answered.'),
    (M, 2739, 'اللهم إني أعوذ بك من زوال نعمتك', 'وجميع سخطك', 'protection', '', '',
     'O Allah, I seek refuge in You from the loss of Your blessings, the change of Your protection, '
     'the suddenness of Your punishment and all of Your anger.'),
    (M, 2716, 'اللهم إني أعوذ بك من شر ما عملت', 'ومن شر ما لم أعمل', 'protection', '', '',
     'O Allah, I seek refuge in You from the evil of what I have done and from the evil of what I '
     'have not done.'),
    (M, 486, 'اللهم أعوذ برضاك من سخطك', 'كما أثنيت على نفسك', 'protection', '', '',
     'O Allah, I seek refuge in Your pleasure from Your anger, in Your pardon from Your punishment, '
     'and I seek refuge in You from You. I cannot count Your praises; You are as You have praised '
     'Yourself.'),
    (M, 2708, 'أعوذ بكلمات الله التامات من شر ما خلق', 'من شر ما خلق', 'protection',
     'عند نزول منزل', 'When stopping at a place',
     'I seek refuge in the perfect words of Allah from the evil of what He has created.'),

    # ---- hardship
    (B, 6346, 'لا إله إلا الله العظيم الحليم', 'رب العرش الكريم', 'hardship',
     'دعاء الكرب', 'In distress',
     'There is no god but Allah, the Mighty, the Forbearing. There is no god but Allah, Lord of the '
     'Mighty Throne. There is no god but Allah, Lord of the heavens, Lord of the earth and Lord of '
     'the Noble Throne.'),
    (M, 918, 'إنا لله وإنا إليه راجعون', 'خيرا منها', 'hardship',
     'عند المصيبة', 'When struck by a calamity',
     'To Allah we belong and to Him we return. O Allah, reward me for my calamity and replace it '
     'for me with something better.'),
    (B, 5671, 'اللهم أحيني ما كانت الحياة خيرا لي', 'إذا كانت الوفاة خيرا لي', 'hardship',
     'لمن اشتد عليه البلاء', 'For one in severe hardship',
     'O Allah, keep me alive as long as life is better for me, and take me when death is better '
     'for me.'),
    (B, 2966, 'اللهم منزل الكتاب', 'وانصرنا عليهم', 'hardship',
     'عند لقاء العدو', 'When facing the enemy',
     'O Allah, Revealer of the Book, Mover of the clouds, Defeater of the confederates, defeat them '
     'and give us victory over them.'),

    # ---- family
    (B, 6388, 'باسم الله اللهم جنبنا الشيطان', 'ما رزقتنا', 'family',
     'عند إتيان الأهل', 'Before intimacy with one\'s spouse',
     'In the name of Allah. O Allah, keep Satan away from us and keep Satan away from what You '
     'grant us.'),
    (B, 3371, 'أعوذ بكلمات الله التامة', 'من كل عين لامة', 'family',
     'تعويذ الأولاد', 'Seeking protection for children',
     'I seek refuge in the perfect words of Allah from every devil and every poisonous creature, '
     'and from every evil eye. (The Prophet ﷺ said it over al-Hasan and al-Husayn.)'),

    # ---- good of this world and the next
    (B, 6389, 'اللهم ربنا آتنا في الدنيا حسنة', 'عذاب النار', 'goodness',
     'أكثر دعاء النبي ﷺ', "The Prophet's most frequent dua",
     'O Allah, our Lord, give us good in this world and good in the Hereafter, and protect us from '
     'the punishment of the Fire.'),
    (M, 2712, 'اللهم خلقت نفسي', 'أسألك العافية', 'goodness',
     'عند النوم', 'Before sleeping',
     'O Allah, You created my soul and You take it; its death and its life are Yours. If You keep '
     'it alive, protect it, and if You cause it to die, forgive it. O Allah, I ask You for '
     'well-being.'),

    # ---- praise
    (B, 6357, 'اللهم صل على محمد', 'كما باركت على آل إبراهيم إنك حميد مجيد', 'praise',
     'الصلاة على النبي ﷺ', 'Sending blessings on the Prophet ﷺ',
     'O Allah, send prayers upon Muhammad and the family of Muhammad as You sent prayers upon the '
     'family of Ibrahim; You are Praiseworthy, Glorious. O Allah, bless Muhammad and the family of '
     'Muhammad as You blessed the family of Ibrahim; You are Praiseworthy, Glorious.'),
    (B, 1120, 'اللهم لك الحمد أنت قيم السموات', 'أنت المقدم وأنت المؤخر لا إله إلا أنت', 'praise',
     'في قيام الليل', 'In the night prayer',
     'O Allah, to You belongs the praise; You are the Sustainer of the heavens and the earth and '
     'whoever is in them. To You belongs the praise; Yours is the dominion of the heavens and the '
     'earth and whoever is in them. To You belongs the praise; You are the Light of the heavens '
     'and the earth. To You belongs the praise; You are the Truth, Your promise is true, meeting '
     'You is true, Your word is true, Paradise is true, the Fire is true, the prophets are true, '
     'Muhammad ﷺ is true, and the Hour is true. O Allah, to You I have submitted, in You I '
     'believe, in You I trust, to You I turn, by You I argue and to You I bring my case. So forgive '
     'me what I have done and what I will do, what I did in secret and what I did openly. You '
     'bring forward and You put back; there is no god but You.'),
    (M, 2713, 'اللهم رب السموات ورب الأرض', 'وأغننا من الفقر', 'praise',
     'عند النوم', 'Before sleeping',
     'O Allah, Lord of the heavens, Lord of the earth and Lord of the Mighty Throne, our Lord and '
     'Lord of all things, Splitter of the seed and the date-stone, Revealer of the Torah, the '
     'Gospel and the Criterion, I seek refuge in You from the evil of every thing whose forelock '
     'You hold. O Allah, You are the First, there is nothing before You; You are the Last, there is '
     'nothing after You; You are the Manifest, there is nothing above You; You are the Hidden, '
     'there is nothing beyond You. Settle our debt for us and free us from poverty.'),
    (M, 477, 'ربنا لك الحمد ملء السموات', 'منك الجد', 'praise',
     'بعد الرفع من الركوع', 'Rising from bowing',
     'Our Lord, to You belongs the praise, filling the heavens and the earth and filling whatever '
     'You will besides. You are worthy of praise and glory; the truest thing a servant has said, '
     'and we are all Your servants: O Allah, none can withhold what You give, none can give what '
     'You withhold, and the wealth of the wealthy does not avail him against You.'),
    (B, 6330, 'لا إله إلا الله وحده لا شريك له', 'منك الجد', 'praise',
     'بعد الصلاة', 'After the prayer',
     'There is no god but Allah alone, without partner; His is the dominion and His is the praise, '
     'and He has power over all things. O Allah, none can withhold what You give, none can give '
     'what You withhold, and the wealth of the wealthy does not avail him against You.'),
    (M, 591, 'اللهم أنت السلام', 'ذا الجلال والإكرام', 'praise',
     'بعد السلام من الصلاة', 'After ending the prayer',
     'O Allah, You are Peace and from You is peace. Blessed are You, Owner of majesty and honour.'),

    # ---- occasions
    (B, 142, 'اللهم إني أعوذ بك من الخبث', 'والخبائث', 'occasions',
     'عند دخول الخلاء', 'Entering the toilet',
     'O Allah, I seek refuge in You from the male and female devils.'),
    (B, 6313, 'اللهم أسلمت نفسي إليك', 'وبنبيك الذي أرسلت', 'occasions',
     'عند النوم', 'Before sleeping',
     'O Allah, I have submitted my soul to You, entrusted my affair to You, turned my face to You '
     'and leaned my back on You, in hope and in fear of You. There is no refuge and no escape from '
     'You except to You. I believe in Your Book which You revealed and in Your Prophet whom You '
     'sent.'),
    (B, 6320, 'باسمك رب وضعت جنبي', 'عبادك الصالحين', 'occasions',
     'عند النوم', 'Before sleeping',
     'In Your name, my Lord, I lay down my side, and by You I raise it. If You keep my soul, have '
     'mercy on it, and if You send it back, protect it with what You protect Your righteous '
     'servants.'),
    (M, 2711, 'اللهم باسمك أحيا', 'وباسمك أموت', 'occasions',
     'عند النوم', 'Before sleeping',
     'O Allah, in Your name I live and in Your name I die.'),
    (M, 2711, 'الحمد لله الذي أحيانا', 'وإليه النشور', 'occasions',
     'عند الاستيقاظ', 'On waking up',
     'Praise be to Allah who gave us life after He had caused us to die, and to Him is the '
     'resurrection.'),
    (M, 2723, 'أمسينا وأمسى الملك لله', 'وعذاب في القبر', 'occasions',
     'في المساء', 'In the evening',
     'We have reached the evening and the dominion belongs to Allah. Praise be to Allah; there is '
     'no god but Allah alone, without partner. His is the dominion and His is the praise, and He '
     'has power over all things. My Lord, I ask You for the good of what is in this night and the '
     'good of what comes after it, and I seek refuge in You from the evil of what is in this night '
     'and the evil of what comes after it. My Lord, I seek refuge in You from laziness and the evil '
     'of old age. My Lord, I seek refuge in You from a punishment in the Fire and a punishment in '
     'the grave. (In the morning say: "We have reached the morning and the dominion belongs to '
     'Allah", and "this day".)'),
    (B, 614, 'اللهم رب هذه الدعوة التامة', 'الذي وعدته', 'occasions',
     'بعد الأذان', 'After the call to prayer',
     'O Allah, Lord of this perfect call and of the prayer about to be established, give Muhammad '
     'the Wasilah and the virtue, and raise him to the praised station that You promised him.'),
    (M, 713, 'اللهم افتح لي أبواب رحمتك', 'أبواب رحمتك', 'occasions',
     'عند دخول المسجد', 'Entering the mosque',
     'O Allah, open for me the doors of Your mercy.'),
    (M, 713, 'اللهم إني أسألك من فضلك', 'من فضلك', 'occasions',
     'عند الخروج من المسجد', 'Leaving the mosque',
     'O Allah, I ask You of Your bounty.'),
    (M, 1342, 'سبحان الذي سخر لنا هذا', 'في المال والأهل', 'occasions',
     'دعاء السفر', 'Setting out on a journey',
     'Glory be to Him who has subjected this to us, and we could never have done it ourselves, '
     'and to our Lord we will surely return. O Allah, we ask You on this journey of ours for '
     'righteousness and piety, and for deeds that please You. O Allah, make this journey easy for '
     'us and shorten its distance for us. O Allah, You are the Companion on the journey and the '
     'One left in charge of the family. O Allah, I seek refuge in You from the hardship of travel, '
     'from a distressing sight, and from an evil return to wealth and family.'),
    (M, 1342, 'آيبون تائبون', 'لربنا حامدون', 'occasions',
     'عند الرجوع من السفر', 'Returning from a journey',
     'Returning, repenting, worshipping, and praising our Lord.'),
    (M, 1184, 'لبيك اللهم لبيك', 'والملك لا شريك لك', 'occasions',
     'التلبية', 'The Talbiyah',
     'Here I am, O Allah, here I am. Here I am, You have no partner, here I am. All praise, '
     'blessings and dominion are Yours; You have no partner.'),
    (M, 897, 'اللهم أغثنا', 'اللهم أغثنا', 'occasions',
     'عند طلب المطر', 'Asking for rain',
     'O Allah, send us rain. (Said three times.)'),
    (M, 897, 'اللهم حولنا ولا علينا', 'ومنابت الشجر', 'occasions',
     'عند كثرة المطر', 'When rain is too much',
     'O Allah, around us and not upon us. O Allah, on the hills, the high ground, the valleys and '
     'where trees grow.'),
    (M, 899, 'اللهم إني أسألك خيرها', 'وشر ما أرسلت به', 'occasions',
     'عند هبوب الريح', 'When the wind blows',
     'O Allah, I ask You for its good, the good of what it carries and the good of what it was '
     'sent with, and I seek refuge in You from its evil, the evil of what it carries and the evil '
     'of what it was sent with.'),
    (B, 3282, 'أعوذ بالله من الشيطان', 'من الشيطان', 'occasions',
     'عند الغضب', 'When angry',
     'I seek refuge in Allah from Satan.'),
    (B, 5742, 'اللهم رب الناس', 'لا يغادر سقما', 'occasions',
     'رقية المريض', 'For the sick',
     'O Allah, Lord of mankind, Remover of harm, cure; You are the Healer, there is no healer but '
     'You; a cure that leaves no illness behind.'),
    (M, 2202, 'أعوذ بالله وقدرته', 'وأحاذر', 'occasions',
     'عند الألم', 'For pain',
     'I seek refuge in Allah and His power from the evil of what I feel and fear. (Put your hand on '
     'the place of pain, say "In the name of Allah" three times, then this seven times.)'),
    (M, 963, 'اللهم اغفر له وارحمه وعافه', 'من عذاب النار', 'occasions',
     'في صلاة الجنازة', 'In the funeral prayer',
     'O Allah, forgive him, have mercy on him, keep him safe and pardon him. Honour his place of '
     'rest and widen his entrance. Wash him with water, snow and hail, and cleanse him of sins as '
     'You cleanse a white garment of dirt. Give him a home better than his home, a family better '
     'than his family and a spouse better than his spouse. Admit him to Paradise and protect him '
     'from the punishment of the grave, or from the punishment of the Fire.'),
    (M, 975, 'السلام عليكم أهل الديار', 'لنا ولكم العافية', 'occasions',
     'عند زيارة القبور', 'Visiting the graves',
     'Peace be upon you, people of these dwellings, believers and Muslims. We will, if Allah wills, '
     'join you. I ask Allah for well-being for us and for you.'),
    (M, 2042, 'اللهم بارك لهم في ما رزقتهم', 'وارحمهم', 'occasions',
     'دعاء الضيف لأهل البيت', 'A guest\'s dua for the hosts',
     'O Allah, bless them in what You have provided them, forgive them and have mercy on them.'),
    (M, 2055, 'اللهم أطعم من أطعمني', 'من أسقاني', 'occasions',
     'لمن أطعمك', 'For whoever gave you food',
     'O Allah, feed whoever fed me and give drink to whoever gave me drink.'),
]

# Narrators' remarks inside a dua, taken out of the text:
#  Muslim 2723: "قال أراه قال فيهن" (he said: I think he said in them)
#  Bukhari 6365: "يعني فتنة الدجال" (meaning the trial of the Antichrist)
REMARKS = ['قال أراه قال فيهن', 'يعني فتنة الدجال']


def remove_words(text, words):
    n, idx = norm_map(text)
    a = n.find(norm(words))
    if a < 0:
        return text
    b = idx[a + len(norm(words)) - 1] + 1
    while b < len(text) and HARAKAT.match(text[b]):
        b += 1
    return text[:idx[a]] + text[b:]


def tidy(text):
    # the data marks sentence ends and quotes as ‏.‏ and ‏"‏
    text = re.sub(r'\s*‏[."]‏\s*', ' ', text)
    for words in REMARKS:
        text = remove_words(text, words)
    return re.sub(r'\s+', ' ', text).strip()


# Where the dataset's arabicnumber is off from Abdul-Baqi's numbering:
# (book, real number) -> number in the data. Muslim 2654 ("O Turner of the
# hearts") is labelled 2655 there, because the end of 2653 is labelled 2654.
DATA_NUMBER = {(M, 2654): 2655}

hadith = []
for book, num, first, last, topic, title_ar, title_en, english in HADITH:
    assert topic in TOPICS, topic
    want = DATA_NUMBER.get((book, num), num)
    # all narrations with this number that contain the words: keep the
    # shortest cut (some narrations have a narrator's remark in the middle)
    cuts = [c for h in BOOKS[book] if number(book, h) == want
            for c in [cut(h['text'], first, last)] if c]
    if not cuts:
        where = sorted({number(book, h) for h in BOOKS[book] if cut(h['text'], first, last)} - {None})
        sys.exit(f'{book} {num}: "{first} ... {last}" not found there (found in: {where[:8]})')
    found = tidy(min(cuts, key=len))
    # Bukhari 834 has one broken letter in the data (the waw of وَلاَ)
    found = found.replace('��َلاَ', 'وَلاَ')
    assert '�' not in found, f'{book} {num}: broken character in the data'
    hadith.append({
        'ar': found.rstrip('"” .‏'),
        'en': english,
        'book': book,
        'number': num,
        'titleAr': title_ar,
        'titleEn': title_en,
        'topic': topic,
    })

json.dump({
    'quran': quran,
    'hadith': hadith,
    'source': {
        'ar': 'آيات القرآن من نص مصحف تنزيل (api.alquran.cloud) وترجمتها من Sahih International. '
              'الأحاديث منقولة بنصها من صحيح البخاري وصحيح مسلم، وترقيم مسلم ترقيم محمد فؤاد عبد الباقي. '
              'جُمعت الأدعية بمراجعة كل آية وحديث فيه دعاء، واستُبعد ما كان لشخص بعينه أو على قوم بأعيانهم.',
        'en': 'Quran text: Tanzil (api.alquran.cloud), translation: Sahih International. Hadith texts '
              'are quoted word for word from Sahih al-Bukhari and Sahih Muslim (Muslim numbered by '
              'Muhammad Fuad Abdul-Baqi); their English is our own. Every verse and narration with a '
              'supplication was reviewed; duas for or against named people were left out.',
    },
}, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(f'{len(quran)} Quran duas, {len(hadith)} hadith duas -> {OUT}')
