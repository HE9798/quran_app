# Builds assets/manasik/manasik.json for the Hajj & Umrah guide.
#
# The steps are written here (Arabic + English), following the well-known
# guides (Ibn Baz, "al-Tahqiq wal-Idah"; the Saudi Ministry of Hajj guide).
# Every evidence quote is cut word for word from the hadith API data
# (fawazahmed0/hadith-api: ara-bukhari, ara-muslim): the script stops if a
# quote can't be found. Supplications are not stored here: the app loads them
# from the Hisn al-Muslim API (hisnmuslim.com) by chapter number.
# Usage: python build_manasik.py <folder with ara-bukhari.json, ara-muslim.json> <path to assets/manasik/manasik.json>
import json, re, sys

T = sys.argv[1]   # folder with ara-bukhari.json / ara-muslim.json
OUT = sys.argv[2]

B = {x['hadithnumber']: x for x in json.load(open(T + '/ara-bukhari.json', encoding='utf-8'))['hadiths']}
M = {x['hadithnumber']: x for x in json.load(open(T + '/ara-muslim.json', encoding='utf-8'))['hadiths']}
JABIR = 2951  # Muslim 1218, Jabir's description of the Prophet's Hajj

STRIP = re.compile(r'[ً-ْٰـ‏‎]')

def norm_map(s):
    """Text without harakat (and with one alef form), plus where each kept
    character came from in the original."""
    out, idx = [], []
    for i, ch in enumerate(s):
        if STRIP.match(ch):
            continue
        out.append('ا' if ch in 'إأآٱ' else ch)
        idx.append(i)
    return ''.join(out), idx

def norm(s):
    return norm_map(s)[0]

def cut(book, number, start, end):
    """The original (with harakat) text from [start] to the end of [end]."""
    src = (B if book == 'b' else M)[number]['text']
    t, idx = norm_map(src)
    a = t.find(norm(start))
    assert a >= 0, (book, number, start)
    b = t.find(norm(end), a)
    assert b >= 0, (book, number, end)
    b += len(norm(end))
    return re.sub(r'\s+', ' ', src[idx[a]:idx[b - 1] + 1]).strip()

def ev(book, number, start, end, ref_no=None):
    no = ref_no or number
    return {
        'ar': ('رواه البخاري (%s)' if book == 'b' else 'رواه مسلم (%s)') % no,
        'en': ('Sahih al-Bukhari %s' if book == 'b' else 'Sahih Muslim %s') % no,
        'text': cut(book, number, start, end),
    }

def jabir(start, end):
    return ev('m', JABIR, start, end, ref_no=1218)

def step(id, ar, en, when_ar, when_en, points_ar, points_en, duas=(), evidence=()):
    assert len(points_ar) == len(points_en), id
    return {'id': id, 'titleAr': ar, 'titleEn': en, 'whenAr': when_ar, 'whenEn': when_en,
            'pointsAr': points_ar, 'pointsEn': points_en, 'duas': list(duas), 'evidence': list(evidence)}

# ------------------------------------------------------------------ steps

def ihram(kind):
    say = {
        'umrah': ('«لَبَّيْكَ عُمْرَةً»', '"Labbayka ‘umrah" (Here I am for Umrah)'),
        'tamattu': ('«لَبَّيْكَ عُمْرَةً» (متمتعًا بها إلى الحج)', '"Labbayka ‘umrah" (Umrah, to be followed by Hajj)'),
        'qiran': ('«لَبَّيْكَ عُمْرَةً وَحَجًّا»', '"Labbayka ‘umratan wa hajjan" (Here I am for Umrah and Hajj)'),
        'ifrad': ('«لَبَّيْكَ حَجًّا»', '"Labbayka hajjan" (Here I am for Hajj)'),
    }[kind]
    until = {
        'umrah': ('حتى تبدأ الطواف.', 'until you start Tawaf.'),
        'tamattu': ('حتى تبدأ طواف العمرة.', 'until you start the Tawaf of Umrah.'),
        'qiran': ('حتى ترمي جمرة العقبة يوم العيد.', 'until you stone Jamrat al-Aqabah on the day of Eid.'),
        'ifrad': ('حتى ترمي جمرة العقبة يوم العيد.', 'until you stone Jamrat al-Aqabah on the day of Eid.'),
    }[kind]
    return step(
        'ihram', 'الإحرام من الميقات', 'Ihram at the Miqat',
        'عند الميقات، أو بمحاذاته في الطائرة', 'At the Miqat, or when the plane passes it',
        [
            'قبل الإحرام: يُسنّ الاغتسال، والتطيّب في البدن لا في ثياب الإحرام، وأخذ ما تحتاج من الأظافر والشعر.',
            'الرجل يلبس إزارًا ورداءً (والأبيض أفضل) ونعلين، ويكشف رأسه. والمرأة تلبس ما شاءت من الثياب الساترة غير المتزيّنة، ولا تلبس النقاب ولا القفازين.',
            'انوِ الدخول في النسك وقل: %s.' % say[0],
            'إن خشيت ألا تُتمّ نسكك لمرض أو نحوه فاشترط: «فإنْ حبسني حابسٌ فمحِلّي حيث حبستني».',
            'أكثِر من التلبية %s ويرفع الرجل بها صوته، وتخفضه المرأة.' % until[0],
        ],
        [
            'Before Ihram it is Sunnah to bathe, to put perfume on the body (not on the Ihram clothes), and to trim nails and hair as needed.',
            'A man wears two sheets, a waist wrap and a shoulder wrap (white is best), with sandals, and keeps his head uncovered. A woman wears any modest, plain clothing, but no face veil (niqab) and no gloves.',
            'Make the intention to begin and say: %s.' % say[1],
            'If you fear you may not be able to finish (illness, etc.), add the condition: "If anything holds me back, my place of release is where You hold me back."',
            'Repeat the Talbiyah often %s Men say it aloud; women say it quietly.' % until[1],
        ],
        duas=[115],
        evidence=[
            jabir('فأهل بالتوحيد', 'والملك لا شريك لك'),
            ev('b', 5089, 'حجي واشترطي', 'حيث حبستني'),
        ],
    )

def tawaf(kind):
    name = {
        'umrah': ('طواف العمرة', 'Tawaf of Umrah'),
        'tamattu': ('طواف العمرة', 'Tawaf of Umrah'),
        'qiran': ('طواف القدوم', 'Tawaf of arrival (al-Qudum)'),
        'ifrad': ('طواف القدوم', 'Tawaf of arrival (al-Qudum)'),
    }[kind]
    note = {
        'umrah': ('وهو ركن من أركان العمرة.', 'It is a pillar of Umrah.'),
        'tamattu': ('وهو ركن من أركان العمرة.', 'It is a pillar of Umrah.'),
        'qiran': ('وهو سنّة للقارن.', 'It is Sunnah for one doing Qiran.'),
        'ifrad': ('وهو سنّة للمفرد.', 'It is Sunnah for one doing Ifrad.'),
    }[kind]
    return step(
        'tawaf', name[0], name[1],
        'عند وصولك إلى المسجد الحرام', 'When you arrive at al-Masjid al-Haram',
        [
            'ابدأ من الحجر الأسود، واجعل الكعبة عن يسارك، وطُف سبعة أشواط كاملة. %s' % note[0],
            'عند بداية كل شوط: استلم الحجر الأسود وقبّله إن تيسّر، وإلا فأشِر إليه بيدك وقل «الله أكبر»، ولا تزاحم.',
            'يُسنّ للرجل في هذا الطواف الاضطباع (كشف الكتف الأيمن) طوال الطواف، والرَّمَل (الإسراع مع تقارب الخطى) في الأشواط الثلاثة الأولى.',
            'بين الركن اليماني والحجر الأسود قل: ﴿رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ﴾، وادعُ واذكر الله بما شئت في باقي الطواف؛ فليس لكل شوط دعاء مخصوص.',
            'تكون على طهارة (وضوء) في الطواف.',
        ],
        [
            'Start at the Black Stone, keep the Kaaba on your left, and walk seven full rounds. %s' % note[1],
            'At the start of each round, touch and kiss the Black Stone if you easily can; otherwise point to it with your hand and say "Allahu akbar". Do not push through crowds.',
            'For men it is Sunnah in this Tawaf to uncover the right shoulder (idtiba) for the whole Tawaf, and to walk briskly with short steps (raml) in the first three rounds.',
            'Between the Yemeni Corner and the Black Stone say: "Rabbana atina fid-dunya hasanah, wa fil-akhirati hasanah, wa qina ‘adhaban-nar." For the rest of the Tawaf make any dhikr and du‘a you like; no round has a set supplication.',
            'Be in a state of wudu during Tawaf.',
        ],
        duas=[116, 117],
        evidence=[jabir('حتى إذا أتينا البيت', 'ومشى أربعا')],
    )

def rakatain():
    return step(
        'rakatain', 'ركعتا الطواف وماء زمزم', 'Two rak‘ahs after Tawaf, and Zamzam',
        'بعد الانتهاء من الطواف', 'After finishing Tawaf',
        [
            'غطِّ كتفك الأيمن، ثم صلِّ ركعتين خلف مقام إبراهيم إن تيسّر، وإلا ففي أي مكان من المسجد. تقرأ في الأولى ﴿قُلْ يَا أَيُّهَا الْكَافِرُونَ﴾ وفي الثانية ﴿قُلْ هُوَ اللَّهُ أَحَدٌ﴾.',
            'اشرب من ماء زمزم.',
            'ثم ارجع إلى الحجر الأسود فاستلمه إن تيسّر، قبل أن تذهب إلى المسعى.',
        ],
        [
            'Cover your right shoulder again, then pray two rak‘ahs behind Maqam Ibrahim if you can, or anywhere in the mosque. Recite al-Kafirun in the first and al-Ikhlas in the second.',
            'Drink Zamzam water.',
            'Then go back to the Black Stone and touch it if you easily can, before heading to the Sa‘i area.',
        ],
        evidence=[jabir('ثم نفذ إلى مقام إبراهيم', 'ثم رجع إلى الركن فاستلمه')],
    )

def sai(kind):
    name = {
        'umrah': ('السعي بين الصفا والمروة', "Sa'i between as-Safa and al-Marwah"),
        'tamattu': ('سعي العمرة', "Sa'i of Umrah"),
        'qiran': ('سعي الحج (يجوز تقديمه هنا)', "Sa'i of Hajj (may be done now)"),
        'ifrad': ('سعي الحج (يجوز تقديمه هنا)', "Sa'i of Hajj (may be done now)"),
    }[kind]
    extra_ar = {'qiran': 'إن سعيت الآن بعد طواف القدوم فلا سعي عليك بعد طواف الإفاضة، ولك أن تؤخّره إليه.',
                'ifrad': 'إن سعيت الآن بعد طواف القدوم فلا سعي عليك بعد طواف الإفاضة، ولك أن تؤخّره إليه.'}.get(kind)
    extra_en = {'qiran': "If you do Sa'i now, after the Tawaf of arrival, you won't repeat it after Tawaf al-Ifadah; or you can leave it until then.",
                'ifrad': "If you do Sa'i now, after the Tawaf of arrival, you won't repeat it after Tawaf al-Ifadah; or you can leave it until then."}.get(kind)
    pa = [
        'اصعد الصفا، واقرأ عند أول شوط فقط: ﴿إِنَّ الصَّفَا وَالْمَرْوَةَ مِنْ شَعَائِرِ اللَّهِ﴾ وقل: «أبدأ بما بدأ الله به».',
        'استقبل الكعبة وارفع يديك، ووحِّد الله وكبّره بالذكر الوارد ثلاث مرات، وادعُ بما شئت بين ذلك.',
        'انزل إلى المروة ماشيًا، ويُسرع الرجل بين العلمين الأخضرين، ثم افعل على المروة ما فعلت على الصفا.',
        'الذهاب من الصفا إلى المروة شوط، والرجوع شوط آخر: سبعة أشواط تبدأ بالصفا وتنتهي بالمروة.',
        'لا تُشترط الطهارة للسعي، لكنها أفضل.',
    ]
    pe = [
        'Climb as-Safa and, at the start of the first round only, recite: "Innas-Safa wal-Marwata min sha‘a’irillah" and say: "I begin with what Allah began with."',
        'Face the Kaaba, raise your hands, and say the words of tawhid and takbir (below) three times, making du‘a in between.',
        'Walk down to al-Marwah. Men walk fast between the two green markers. On al-Marwah do as you did on as-Safa.',
        'Safa to Marwah is one round, and back is another: seven rounds, starting at as-Safa and ending at al-Marwah.',
        "Wudu is not required for Sa'i, but it is better.",
    ]
    if extra_ar:
        pa.append(extra_ar); pe.append(extra_en)
    return step('sai', name[0], name[1], 'بعد ركعتي الطواف', 'After the two rak‘ahs of Tawaf', pa, pe,
                duas=[118],
                evidence=[jabir('ثم خرج من الباب إلى الصفا', 'ففعل على المروة كما فعل على الصفا')])

def halq_umrah(kind):
    pa = [
        'الرجل يحلق رأسه كله أو يقصّر من جميع شعره، والحلق أفضل. والمرأة تقصّر من أطراف شعرها قدر أنملة.',
        'بهذا تمّت عمرتك، وحلّ لك كل ما كان محرّمًا عليك بالإحرام.',
    ]
    pe = [
        'A man shaves his whole head or shortens hair from all of it; shaving is better. A woman cuts a fingertip’s length from the ends of her hair.',
        'Your Umrah is complete, and everything forbidden by Ihram is allowed again.',
    ]
    if kind == 'tamattu':
        pa.insert(1, 'للمتمتع: الأفضل هنا التقصير، ليبقى شعر يحلقه يوم العيد في الحج.')
        pe.insert(1, 'For Tamattu‘: shortening is better here, so there is hair left to shave on the day of Eid.')
    return step('halq_umrah', 'الحلق أو التقصير', 'Shaving or shortening the hair',
                'بعد السعي', "After Sa'i", pa, pe,
                evidence=[ev('b', 1727, 'اللهم ارحم المحلقين', '" والمقصرين "'),
                          jabir('فحل الناس كلهم وقصروا', 'ومن كان معه هدى')])

def stay_ihram(kind):
    return step('stay', 'البقاء على الإحرام', 'Staying in Ihram',
                'من بعد طواف القدوم إلى يوم العيد', 'From the Tawaf of arrival until the day of Eid',
                [
                    'لا تحلق ولا تقصّر، وابقَ على إحرامك حتى ترمي جمرة العقبة يوم العيد.',
                    'أكثِر من التلبية والذكر حتى يوم التروية.',
                ] + (['القارن عليه هدي (ذبيحة) يوم العيد أو أيام التشريق.'] if kind == 'qiran' else
                     ['المفرد ليس عليه هدي.']),
                [
                    'Do not shave or shorten your hair; stay in Ihram until you stone Jamrat al-Aqabah on the day of Eid.',
                    'Keep saying the Talbiyah and remembering Allah until the 8th.',
                ] + (['One doing Qiran must offer a sacrifice (hady) on Eid or the days after it.'] if kind == 'qiran' else
                     ['One doing Ifrad has no sacrifice to offer.']),
                evidence=[ev('b', 1562, 'فأما من أهل بالحج', 'حتى كان يوم النحر')])

def tarwiyah(kind):
    first_ar = {'tamattu': 'أحرِم بالحج ضحىً من مكانك في مكة كما أحرمت من الميقات (اغتسال وطيب ولباس الإحرام) وقل: «لَبَّيْكَ حَجًّا».',
                'qiran': 'أنت باقٍ على إحرامك، فلا تحتاج إحرامًا جديدًا.',
                'ifrad': 'أنت باقٍ على إحرامك، فلا تحتاج إحرامًا جديدًا.'}[kind]
    first_en = {'tamattu': 'In the late morning, enter Ihram for Hajj from where you are staying in Makkah, as you did at the Miqat (bath, perfume, Ihram clothes), and say: "Labbayka hajjan."',
                'qiran': 'You are still in Ihram, so there is nothing new to do.',
                'ifrad': 'You are still in Ihram, so there is nothing new to do.'}[kind]
    return step('tarwiyah', 'يوم التروية: إلى منى', 'Day of Tarwiyah: to Mina',
                '٨ ذو الحجة', '8 Dhul-Hijjah',
                [
                    first_ar,
                    'اذهب إلى منى، وصلِّ بها الظهر والعصر والمغرب والعشاء، ثم فجر يوم عرفة: كل صلاة في وقتها، وتُقصر الرباعية بلا جمع.',
                    'بِت ليلة التاسع بمنى (سنّة)، وأكثر من التلبية.',
                ],
                [
                    first_en,
                    'Go to Mina and pray Dhuhr, Asr, Maghrib and Isha there, then Fajr of the day of Arafah: each in its own time, with four-rak‘ah prayers shortened to two, not combined.',
                    'Spend the night of the 9th in Mina (Sunnah), saying the Talbiyah often.',
                ],
                duas=[115],
                evidence=[jabir('فلما كان يوم التروية', 'والعشاء والفجر')])

def arafah():
    return step('arafah', 'يوم عرفة: الوقوف بعرفة', 'Day of Arafah: standing at Arafah',
                '٩ ذو الحجة', '9 Dhul-Hijjah',
                [
                    'بعد طلوع الشمس سِر من منى إلى عرفة.',
                    'بعد الزوال صلِّ الظهر والعصر جمعًا وقصرًا في وقت الظهر، بأذان واحد وإقامتين.',
                    'تأكّد أنك داخل حدود عرفة، ثم تفرّغ للدعاء والذكر والتلبية مستقبلًا القبلة حتى تغرب الشمس. ولا يلزم صعود جبل الرحمة.',
                    'الوقوف بعرفة أعظم أركان الحج، فمن فاته فاته الحج. ووقته من زوال يوم ٩ إلى فجر يوم ١٠، ومن وقف نهارًا بقي حتى الغروب.',
                ],
                [
                    'After sunrise, travel from Mina to Arafah.',
                    'After midday, pray Dhuhr and Asr together, shortened, at the time of Dhuhr, with one adhan and two iqamahs.',
                    'Make sure you are inside the boundaries of Arafah, then devote yourself to du‘a, dhikr and the Talbiyah, facing the Qiblah, until sunset. There is no need to climb Jabal ar-Rahmah.',
                    'Standing at Arafah is the greatest pillar of Hajj: whoever misses it has missed Hajj. Its time runs from midday on the 9th to Fajr on the 10th; if you stand in the daytime, stay until sunset.',
                ],
                duas=[119],
                evidence=[jabir('ثم أذن ثم أقام فصلى الظهر', 'حتى غاب القرص')])

def muzdalifah():
    return step('muzdalifah', 'المبيت بمزدلفة', 'The night at Muzdalifah',
                'ليلة ١٠ ذو الحجة', 'The night before 10 Dhul-Hijjah',
                [
                    'بعد غروب الشمس انصرف إلى مزدلفة بسكينة، وأنت تلبّي.',
                    'حين تصل صلِّ المغرب والعشاء جمعًا (والعشاء ركعتان) بأذان وإقامتين.',
                    'بِت بها، وصلِّ الفجر أول وقته، ثم قف عند المشعر الحرام (أو في أي مكان من مزدلفة) مستقبل القبلة تدعو وتذكر الله حتى يُسفر جدًّا، ثم انصرف قبل طلوع الشمس.',
                    'يجوز للضعفاء والنساء ومن معهم الانصراف بعد منتصف الليل.',
                    'التقط سبع حصيات لرمي جمرة العقبة، أكبر قليلًا من حبة الحمص، من مزدلفة أو من أي مكان.',
                ],
                [
                    'After sunset, leave calmly for Muzdalifah, saying the Talbiyah.',
                    'When you arrive, pray Maghrib and Isha together (Isha as two rak‘ahs) with one adhan and two iqamahs.',
                    'Spend the night there and pray Fajr early. Then stand at al-Mash‘ar al-Haram (or anywhere in Muzdalifah) facing the Qiblah, making du‘a and dhikr until it is quite light, and leave before sunrise.',
                    'The weak, women and those with them may leave after midnight.',
                    'Pick up seven pebbles for Jamrat al-Aqabah, a little bigger than a chickpea, from Muzdalifah or anywhere.',
                ],
                duas=[120],
                evidence=[jabir('حتى أتى المزدلفة', 'فدفع قبل أن تطلع الشمس')])

def nahr(kind):
    hady = kind in ('tamattu', 'qiran')
    sai_ar = {'tamattu': 'ثم اسعَ بين الصفا والمروة سعي الحج.',
              'qiran': 'ثم اسعَ سعي الحج إن لم تكن سعيت بعد طواف القدوم.',
              'ifrad': 'ثم اسعَ سعي الحج إن لم تكن سعيت بعد طواف القدوم.'}[kind]
    sai_en = {'tamattu': "Then do the Sa'i of Hajj between as-Safa and al-Marwah.",
              'qiran': "Then do the Sa'i of Hajj, if you did not do it after the Tawaf of arrival.",
              'ifrad': "Then do the Sa'i of Hajj, if you did not do it after the Tawaf of arrival."}[kind]
    pa = ['ارمِ جمرة العقبة وحدها بسبع حصيات متتابعات، تكبّر مع كل حصاة، واقطع التلبية مع بدء الرمي.']
    pe = ['Stone Jamrat al-Aqabah only, with seven pebbles one after another, saying "Allahu akbar" with each. Stop the Talbiyah when you start.']
    if hady:
        pa.append('اذبح الهدي (من يوم العيد إلى غروب شمس ١٣ ذو الحجة)، وكُل منه وأطعم الفقراء. ومن لم يجد الهدي صام ثلاثة أيام في الحج وسبعة إذا رجع إلى أهله.')
        pe.append('Offer your sacrifice (hady), any time from Eid until sunset on the 13th; eat from it and feed the poor. If you cannot, fast three days during Hajj and seven when you are home.')
    pa += [
        'احلق رأسك أو قصّر، والحلق أفضل للرجل، والمرأة تقصّر قدر أنملة. بعد الرمي والحلق تتحلّل التحلّل الأول: يحلّ لك كل شيء إلا النساء.',
        'انزل إلى مكة وطُف طواف الإفاضة (ركن من أركان الحج). ' + sai_ar + ' وبذلك تتحلّل التحلّل الثاني الكامل.',
        'الأفضل هذا الترتيب: الرمي، ثم الذبح، ثم الحلق، ثم الطواف. ومن قدّم شيئًا أو أخّره فلا حرج. ويجوز تأخير طواف الإفاضة إلى ما بعد أيام التشريق.',
    ]
    pe += [
        'Shave your head or shorten your hair (shaving is better for men; women cut a fingertip’s length). After stoning and shaving you are partly out of Ihram: everything is allowed except marital relations.',
        'Go to Makkah for Tawaf al-Ifadah, a pillar of Hajj. ' + sai_en + ' You are then fully out of Ihram.',
        'The best order is: stoning, sacrifice, shaving, then Tawaf. Doing one before another is fine. Tawaf al-Ifadah may also be delayed until after the days of Tashreeq.',
    ]
    return step('nahr', 'يوم النحر (العيد)', 'Day of Sacrifice (Eid)', '١٠ ذو الحجة', '10 Dhul-Hijjah',
                pa, pe, duas=[121],
                evidence=[jabir('حتى أتى الجمرة التي عند الشجرة', 'فأفاض إلى البيت'),
                          ev('b', 1736, 'فقال رجل لم أشعر', 'إلا قال افعل ولا حرج')])

def tashreeq():
    return step('tashreeq', 'أيام التشريق: المبيت بمنى ورمي الجمرات', 'Days of Tashreeq: Mina and the three Jamarat',
                '١١ و١٢ (و١٣) ذو الحجة', '11, 12 (and 13) Dhul-Hijjah',
                [
                    'بِت بمنى ليلتي ١١ و١٢ (وليلة ١٣ إن تأخرت).',
                    'كل يوم بعد الزوال ارمِ الجمرات الثلاث بالترتيب، كل جمرة بسبع حصيات تكبّر مع كل حصاة: الصغرى، ثم تقدّم وقف مستقبل القبلة وادعُ طويلًا؛ ثم الوسطى وقف وادعُ كذلك؛ ثم جمرة العقبة ولا تقف بعدها.',
                    'من أراد التعجّل خرج من منى بعد رمي يوم ١٢ قبل غروب الشمس. ومن غربت عليه الشمس وهو بمنى بات ورمى يوم ١٣.',
                    'من عجز عن الرمي لمرض أو كبر ونحوهما وكّل من يرمي عنه.',
                ],
                [
                    'Spend the nights of the 11th and 12th in Mina (and the 13th if you stay on).',
                    'Each day after midday, stone the three Jamarat in order, seven pebbles each, saying "Allahu akbar" with each: the small one, then step forward, face the Qiblah and make a long du‘a; then the middle one, and stand and make du‘a again; then Jamrat al-Aqabah, without stopping after it.',
                    'If you want to leave early, leave Mina after stoning on the 12th, before sunset. If the sun sets while you are still in Mina, stay the night and stone on the 13th.',
                    'Anyone unable to stone (illness, old age, etc.) may appoint someone to stone for them.',
                ],
                duas=[121],
                evidence=[ev('b', 1751, 'أنه كان يرمي الجمرة الدنيا', 'يفعله')])

def wada():
    return step('wada', 'طواف الوداع', 'Farewell Tawaf',
                'قبل سفرك من مكة', 'Before leaving Makkah',
                [
                    'إذا أردت السفر من مكة فطُف بالبيت سبعة أشواط ليكون آخر عهدك بالبيت، بلا سعي، ثم سافر.',
                    'يسقط طواف الوداع عن الحائض والنفساء.',
                ],
                [
                    'When you are ready to leave Makkah, walk seven rounds around the Kaaba so it is your last act there (no Sa\'i), then travel.',
                    'Women with their period or postnatal bleeding are excused from it.',
                ],
                evidence=[ev('b', 1755, 'أمر الناس', 'خفف عن الحائض')])

def travel():
    return step('travel', 'السفر والعودة', 'Travelling there and back',
                'في الطريق', 'On the way',
                [
                    'قل دعاء السفر إذا ركبت، وأكثِر من الذكر في الطريق.',
                    'وإذا رجعت إلى بلدك فقل ذكر الرجوع من السفر.',
                ],
                [
                    'Say the travel supplication when you set off, and remember Allah often on the way.',
                    'When you return home, say the supplication for returning from a journey.',
                ],
                duas=[96, 105])

# ----------------------------------------------------------------- guides

guides = [
    {
        'id': 'umrah', 'titleAr': 'العمرة', 'titleEn': 'Umrah',
        'introAr': 'أركان العمرة: الإحرام، والطواف، والسعي. وواجباتها: الإحرام من الميقات، والحلق أو التقصير.',
        'introEn': 'The pillars of Umrah are Ihram, Tawaf and Sa\'i. Its obligations are entering Ihram at the Miqat, and shaving or shortening the hair.',
        'steps': [travel(), ihram('umrah'), tawaf('umrah'), rakatain(), sai('umrah'), halq_umrah('umrah')],
    },
    {
        'id': 'tamattu', 'titleAr': 'حج التمتع', 'titleEn': 'Hajj Tamattu‘',
        'introAr': 'تُحرم بالعمرة وحدها في أشهر الحج، فتؤدّيها وتتحلّل، ثم تُحرم بالحج يوم التروية من عامك. وعليك الهدي. وهو أيسر الأنساك وأكثرها اختيارًا للقادمين من خارج مكة.',
        'introEn': 'You enter Ihram for Umrah only during the Hajj months, complete it and leave Ihram, then enter Ihram for Hajj on the 8th of the same year. A sacrifice (hady) is due. It is the easiest form, and the one most pilgrims from outside Makkah choose.',
        'steps': [travel(), ihram('tamattu'), tawaf('tamattu'), rakatain(), sai('tamattu'), halq_umrah('tamattu'),
                  tarwiyah('tamattu'), arafah(), muzdalifah(), nahr('tamattu'), tashreeq(), wada()],
    },
    {
        'id': 'qiran', 'titleAr': 'حج القِران', 'titleEn': 'Hajj Qiran',
        'introAr': 'تُحرم بالعمرة والحج معًا، وتبقى على إحرامك حتى يوم العيد، ويكفيك طواف واحد وسعي واحد لهما. وعليك الهدي.',
        'introEn': 'You enter Ihram for Umrah and Hajj together and stay in Ihram until Eid; one Tawaf and one Sa\'i count for both. A sacrifice (hady) is due.',
        'steps': [travel(), ihram('qiran'), tawaf('qiran'), rakatain(), sai('qiran'), stay_ihram('qiran'),
                  tarwiyah('qiran'), arafah(), muzdalifah(), nahr('qiran'), tashreeq(), wada()],
    },
    {
        'id': 'ifrad', 'titleAr': 'حج الإفراد', 'titleEn': 'Hajj Ifrad',
        'introAr': 'تُحرم بالحج وحده، وتبقى على إحرامك حتى يوم العيد. وأعماله كأعمال القِران، إلا أنه لا هدي عليك.',
        'introEn': 'You enter Ihram for Hajj only and stay in Ihram until Eid. The rites are the same as Qiran, but no sacrifice is due.',
        'steps': [travel(), ihram('ifrad'), tawaf('ifrad'), rakatain(), sai('ifrad'), stay_ihram('ifrad'),
                  tarwiyah('ifrad'), arafah(), muzdalifah(), nahr('ifrad'), tashreeq(), wada()],
    },
]

# ------------------------------------------------------- reference cards

info = [
    {
        'id': 'types', 'titleAr': 'أنواع النسك الثلاثة', 'titleEn': 'The three ways of doing Hajj',
        'pointsAr': [
            'التمتع: عمرة في أشهر الحج ثم تحلّل، ثم إحرام بالحج يوم التروية. وعليه هدي.',
            'القِران: إحرام بالعمرة والحج معًا والبقاء على الإحرام حتى يوم العيد. وعليه هدي.',
            'الإفراد: إحرام بالحج وحده حتى يوم العيد. ولا هدي عليه.',
        ],
        'pointsEn': [
            'Tamattu‘: Umrah in the Hajj months, leave Ihram, then Ihram for Hajj on the 8th. A sacrifice is due.',
            'Qiran: Ihram for Umrah and Hajj together, staying in Ihram until Eid. A sacrifice is due.',
            'Ifrad: Ihram for Hajj only, until Eid. No sacrifice is due.',
        ],
        'evidence': [ev('b', 1562, 'خرجنا مع رسول الله', 'حتى كان يوم النحر')],
    },
    {
        'id': 'mawaqit', 'titleAr': 'المواقيت', 'titleEn': 'The Miqat points',
        'pointsAr': [
            'ذو الحليفة (أبيار علي): لأهل المدينة ومن مرّ بها.',
            'الجحفة (ويُحرم الناس اليوم من رابغ): لأهل الشام ومصر والمغرب.',
            'قرن المنازل (السيل الكبير، ووادي محرم): لأهل نجد والطائف.',
            'يلملم (السعدية): لأهل اليمن.',
            'ذات عرق (الضريبة): لأهل العراق.',
            'من كان دون المواقيت أحرم من مكانه، وأهل مكة يُحرمون بالحج من مكة، وبالعمرة من الحِلّ (كالتنعيم).',
            'من كان في الطائرة أحرم إذا حاذى الميقات، فيتهيّأ قبل ذلك.',
        ],
        'pointsEn': [
            'Dhul-Hulayfah (Abyar Ali): for the people of Madinah and anyone passing it.',
            'Al-Juhfah (people now use Rabigh): for the people of Sham, Egypt and the Maghreb.',
            'Qarn al-Manazil (as-Sayl al-Kabir, Wadi Muhrim): for the people of Najd and Taif.',
            'Yalamlam (as-Sa‘diyyah): for the people of Yemen.',
            'Dhat ‘Irq (adh-Dharibah): for the people of Iraq.',
            'Anyone living inside these points enters Ihram from home. People in Makkah enter Ihram for Hajj from Makkah, and for Umrah from outside the Haram (e.g. at-Tan‘im).',
            'On a plane, enter Ihram when the plane passes the Miqat, so get ready before then.',
        ],
        'evidence': [ev('b', 1524, 'وقت لأهل المدينة', 'حتى أهل مكة من مكة'),
                     ev('b', 1531, 'لما فتح هذان المصران', 'فحد لهم ذات عرق')],
    },
    {
        'id': 'arkan', 'titleAr': 'أركان الحج وواجباته', 'titleEn': 'Pillars and obligations of Hajj',
        'pointsAr': [
            'أركان الحج (لا يصحّ الحج بدونها): الإحرام، والوقوف بعرفة، وطواف الإفاضة، والسعي.',
            'واجبات الحج: الإحرام من الميقات، والبقاء بعرفة إلى الغروب لمن وقف نهارًا، والمبيت بمزدلفة، والمبيت بمنى ليالي التشريق، ورمي الجمرات، والحلق أو التقصير، وطواف الوداع.',
            'من ترك واجبًا فعليه دم (ذبيحة تُوزّع على فقراء الحرم) عند جمهور العلماء، وحجّه صحيح.',
            'وما سوى ذلك سنن: كطواف القدوم، والمبيت بمنى ليلة عرفة، والرمل والاضطباع.',
        ],
        'pointsEn': [
            'Pillars of Hajj (Hajj is not valid without them): Ihram, standing at Arafah, Tawaf al-Ifadah, and Sa\'i.',
            'Obligations: Ihram from the Miqat; staying at Arafah until sunset if you stood in the day; the night at Muzdalifah; the nights of Tashreeq in Mina; stoning the Jamarat; shaving or shortening; and the Farewell Tawaf.',
            'Most scholars say that leaving out an obligation requires a sacrifice (given to the poor of the Haram), and the Hajj is still valid.',
            'Everything else is Sunnah, such as the Tawaf of arrival, the night in Mina before Arafah, raml and idtiba.',
        ],
        'evidence': [],
    },
    {
        'id': 'mahzurat', 'titleAr': 'محظورات الإحرام', 'titleEn': 'What is forbidden in Ihram',
        'pointsAr': [
            'إزالة الشعر وتقليم الأظافر.',
            'الطيب في البدن أو الثوب بعد الإحرام.',
            'للرجل: لبس المخيط (كالقميص والسراويل والعمامة والخف)، وتغطية الرأس.',
            'للمرأة: لبس النقاب والقفازين، وتستر وجهها عن الرجال الأجانب بغير النقاب.',
            'قتل الصيد البري أو المساعدة عليه.',
            'عقد النكاح.',
            'الجماع ومقدماته، وهو أشدّها.',
            'من فعل شيئًا منها ناسيًا أو جاهلًا فلا شيء عليه، ويكفّ عنه متى تذكّر أو علم.',
        ],
        'pointsEn': [
            'Removing hair or cutting nails.',
            'Using perfume on the body or clothes after entering Ihram.',
            'For men: wearing sewn, fitted clothing (shirts, trousers, turbans, closed shoes), and covering the head.',
            'For women: wearing a face veil (niqab) or gloves; she may cover her face from unrelated men in other ways.',
            'Hunting land animals, or helping someone hunt.',
            'Making a marriage contract.',
            'Marital relations and anything leading to them: the most serious of all.',
            'Anyone who does one of these by forgetting or not knowing owes nothing, and stops once they remember or learn.',
        ],
        'evidence': [ev('b', 1838, 'لا تلبسوا القميص', 'ولا تلبس القفازين')],
    },
    {
        'id': 'women', 'titleAr': 'الحائض والنفساء', 'titleEn': 'During a period or postnatal bleeding',
        'pointsAr': [
            'تُحرم وتفعل كل ما يفعله الحاج من وقوف ومبيت ورمي وذكر، إلا الطواف بالبيت حتى تطهر.',
            'المتمتعة إن حاضت قبل طواف العمرة وخشيت فوات الحج أدخلت الحج على العمرة فصارت قارنة.',
            'يسقط عنها طواف الوداع.',
        ],
        'pointsEn': [
            'She enters Ihram and does everything other pilgrims do (standing, staying overnight, stoning, dhikr) except Tawaf, until she is pure.',
            'If a woman doing Tamattu‘ has her period before the Tawaf of Umrah and fears missing Hajj, she adds Hajj to her Umrah and becomes one doing Qiran.',
            'She is excused from the Farewell Tawaf.',
        ],
        'evidence': [ev('b', 305, 'فإن ذلك شىء كتبه الله', 'حتى تطهري')],
    },
]

data = {
    'source': {
        'ar': 'الخطوات مكتوبة وفق المناسك المعروفة (التحقيق والإيضاح للشيخ ابن باز، ودليل الحاج والمعتمر). الأدعية من حصن المسلم (hisnmuslim.com)، والأدلة من صحيحي البخاري ومسلم.',
        'en': 'Steps follow the well-known manasik guides (Ibn Baz, al-Tahqiq wal-Idah; the pilgrim\'s guide). Supplications are from Hisn al-Muslim (hisnmuslim.com); evidence is from Sahih al-Bukhari and Sahih Muslim.',
    },
    'guides': guides,
    'info': info,
    'jabir': {'ar': 'رواه مسلم (1218)', 'en': 'Sahih Muslim 1218', 'text': M[JABIR]['text'].strip()},
}
json.dump(data, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('guides', [(g['id'], len(g['steps'])) for g in guides], 'info', len(info))
