/// The adhan voices the user can choose for prayer notifications.
///
/// Android can only play a notification sound from a file inside the app, so
/// these recordings are bundled in android/app/src/main/res/raw/. They come
/// from the public Kiwifu/adhan-mp3 collection on GitHub. Each voice has its
/// own Fajr recording (it contains «الصلاة خير من النوم»).
class AdhanVoice {
  const AdhanVoice(this.id, this.arabic, this.english);

  final String id;
  final String arabic;
  final String english;

  /// Android raw resource names (no extension).
  String get regularRes => 'adhan_$id';
  String get fajrRes => 'adhan_${id}_fajr';

  String label(bool isArabic) => isArabic ? arabic : english;

  static const all = [
    AdhanVoice('makkah', 'الحرم المكي · علي ملا', 'Makkah · Ali Mala'),
    AdhanVoice('madinah', 'الحرم المدني', 'Madinah · Al-Haram Al-Madani'),
    AdhanVoice('alafasy', 'مشاري راشد العفاسي', 'Mishary Alafasy'),
    AdhanVoice('abdulbasit', 'عبد الباسط عبد الصمد', 'Abdulbasit Abdusamad'),
    AdhanVoice('kuwait', 'أذان الكويت', 'Kuwait'),
  ];

  static const defaultId = 'makkah';

  static AdhanVoice byId(String id) =>
      all.firstWhere((v) => v.id == id, orElse: () => all.first);
}
