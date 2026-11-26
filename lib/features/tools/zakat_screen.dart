import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';

/// Zakat calculator. The nisab is 85 g of gold (default) or 595 g of silver,
/// and zakat is 2.5% of the wealth that is held above it for a lunar year.
/// The app has no price feed, so the user types today's price per gram; the
/// prices, the gold/silver choice and the currency are remembered.
class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});

  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  static const _goldNisabGrams = 85.0;
  static const _silverNisabGrams = 595.0;
  static const _rate = 0.025;

  static const _kBasis = 'zakat_basis_v1';
  static const _kGold = 'zakat_gold_price_v1';
  static const _kSilver = 'zakat_silver_price_v1';
  static const _kCurrency = 'zakat_currency_v1';

  bool _gold = true; // nisab by gold (default) or silver

  final _goldPrice = TextEditingController();
  final _silverPrice = TextEditingController();
  final _currency = TextEditingController();

  final _cash = TextEditingController();
  final _goldGrams = TextEditingController();
  final _silverGrams = TextEditingController();
  final _invest = TextEditingController();
  final _business = TextEditingController();
  final _owedToYou = TextEditingController();
  final _debts = TextEditingController();

  List<TextEditingController> get _all => [
        _goldPrice, _silverPrice, _currency, _cash, _goldGrams, _silverGrams,
        _invest, _business, _owedToYou, _debts,
      ];

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      c.addListener(() => setState(() {}));
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _gold = (p.getString(_kBasis) ?? 'gold') == 'gold';
        _goldPrice.text = p.getString(_kGold) ?? '';
        _silverPrice.text = p.getString(_kSilver) ?? '';
        _currency.text = p.getString(_kCurrency) ?? '';
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kBasis, _gold ? 'gold' : 'silver');
      await p.setString(_kGold, _goldPrice.text);
      await p.setString(_kSilver, _silverPrice.text);
      await p.setString(_kCurrency, _currency.text);
    } catch (_) {}
  }

  /// "١٢٣٫٥" / "1,200.50" -> number (0 when empty or not a number)
  static double _num(TextEditingController c) {
    var t = c.text.trim();
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < 10; i++) {
      t = t.replaceAll(arabic[i], '$i');
    }
    t = t.replaceAll('٫', '.').replaceAll('٬', '').replaceAll(',', '');
    final v = double.tryParse(t) ?? 0;
    return v < 0 ? 0 : v;
  }

  String _fmt(BuildContext context, double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    final frac = parts[1] == '00' ? '' : '.${parts[1]}';
    final cur = _currency.text.trim();
    final out = '$buf$frac${cur.isEmpty ? '' : ' $cur'}';
    return context.digits(out);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    final goldP = _num(_goldPrice);
    final silverP = _num(_silverPrice);
    final basisPrice = _gold ? goldP : silverP;
    final nisab = (_gold ? _goldNisabGrams : _silverNisabGrams) * basisPrice;

    final goldValue = _num(_goldGrams) * goldP;
    final silverValue = _num(_silverGrams) * silverP;
    final assets = _num(_cash) + goldValue + silverValue + _num(_invest) + _num(_business) + _num(_owedToYou);
    final total = assets - _num(_debts);

    // what is missing before a result can be shown
    String? missing;
    if (basisPrice <= 0) {
      missing = _gold
          ? context.tr("Enter today's gold price per gram to see the result.",
              'أدخل سعر جرام الذهب اليوم لعرض النتيجة.')
          : context.tr("Enter today's silver price per gram to see the result.",
              'أدخل سعر جرام الفضة اليوم لعرض النتيجة.');
    } else if (_num(_goldGrams) > 0 && goldP <= 0) {
      missing = context.tr("Enter today's gold price per gram to count your gold.",
          'أدخل سعر جرام الذهب اليوم لحساب ذهبك.');
    } else if (_num(_silverGrams) > 0 && silverP <= 0) {
      missing = context.tr("Enter today's silver price per gram to count your silver.",
          'أدخل سعر جرام الفضة اليوم لحساب فضتك.');
    }

    final due = missing == null && total >= nisab && total > 0;
    final zakat = due ? total * _rate : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.tr('Back', 'رجوع'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.canPop() ? context.pop() : context.go('/tools'),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                context.tr('Zakat calculator', 'حاسبة الزكاة'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ---------------------------------------------------------- nisab
        _Section(
          title: context.tr('Nisab (the minimum)', 'النصاب (الحد الأدنى)'),
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text(context.tr('Gold · 85 g', 'الذهب · ٨٥ جم'))),
                ButtonSegment(value: false, label: Text(context.tr('Silver · 595 g', 'الفضة · ٥٩٥ جم'))),
              ],
              selected: {_gold},
              onSelectionChanged: (s) {
                setState(() => _gold = s.first);
                _save();
              },
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                'Most people use gold. Silver gives a lower minimum, so zakat applies to more people.',
                'يعتمد أغلب الناس على الذهب. أما الفضة فنصابها أقل، فتجب الزكاة على عدد أكبر.',
              ),
              style: TextStyle(fontSize: 12, color: p.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _goldPrice,
              label: context.tr('Gold price per gram (24k)', 'سعر جرام الذهب (عيار ٢٤)'),
              onChanged: _save,
            ),
            _Field(
              controller: _silverPrice,
              label: context.tr('Silver price per gram', 'سعر جرام الفضة'),
              onChanged: _save,
            ),
            _Field(
              controller: _currency,
              label: context.tr('Currency (optional)', 'العملة (اختياري)'),
              hint: context.tr('e.g. EGP', 'مثال: جنيه'),
              number: false,
              onChanged: _save,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // --------------------------------------------------------- wealth
        _Section(
          title: context.tr('Your wealth', 'أموالك'),
          children: [
            _Field(controller: _cash, label: context.tr('Cash and bank savings', 'النقد والمدخرات في البنك')),
            _Field(controller: _goldGrams, label: context.tr('Gold you own (grams)', 'الذهب الذي تملكه (جرام)')),
            _Field(controller: _silverGrams, label: context.tr('Silver you own (grams)', 'الفضة التي تملكها (جرام)')),
            _Field(controller: _invest, label: context.tr('Investments and shares (value)', 'الاستثمارات والأسهم (القيمة)')),
            _Field(controller: _business, label: context.tr('Business goods for sale (value)', 'بضائع التجارة (القيمة)')),
            _Field(controller: _owedToYou, label: context.tr('Money owed to you (expected back)', 'ديون لك مرجوّة السداد')),
            _Field(controller: _debts, label: context.tr('Debts you owe now (subtracted)', 'ديون عليك حالّة (تُخصم)')),
            Text(
              context.tr(
                'Gold is counted as pure 24k. For 21k gold, multiply its grams by 0.875 first. Your home, car and personal items are not counted.',
                'يُحسب الذهب على أنه عيار ٢٤. لذهب عيار ٢١ اضرب جراماته في ٠٫٨٧٥ أولًا. لا يُحسب بيتك وسيارتك وأغراضك الشخصية.',
              ),
              style: TextStyle(fontSize: 12, color: p.muted, height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // --------------------------------------------------------- result
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: due ? p.hero : p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: due ? Colors.transparent : p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (missing != null)
                Text(missing, style: TextStyle(fontSize: 14, color: p.muted, height: 1.4))
              else ...[
                _ResultRow(
                  label: context.tr('Your zakatable wealth', 'مالك الذي تجب فيه الزكاة'),
                  value: _fmt(context, total < 0 ? 0 : total),
                  light: due,
                ),
                const SizedBox(height: 6),
                _ResultRow(
                  label: context.tr('Nisab', 'النصاب'),
                  value: _fmt(context, nisab),
                  light: due,
                ),
                const Divider(height: 24),
                if (due) ...[
                  Text(
                    context.tr('Zakat due (2.5%)', 'الزكاة الواجبة (٢٫٥٪)'),
                    style: const TextStyle(fontSize: 13, color: Color(0xCCF7EBD4)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmt(context, zakat),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFFF7EBD4)),
                  ),
                ] else
                  Text(
                    total <= 0
                        ? context.tr('Add your wealth above to see the result.', 'أضف أموالك أعلاه لعرض النتيجة.')
                        : context.tr('Below the nisab: no zakat is due.', 'أقل من النصاب: لا زكاة واجبة.'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr(
            'Zakat is due when your wealth stays above the nisab for a full lunar year (hawl). Scholars differ on some details, so ask a scholar about your own case.',
            'تجب الزكاة إذا بقي مالك فوق النصاب سنة هجرية كاملة (الحول). يختلف العلماء في بعض التفاصيل، فاسأل أهل العلم عن حالتك.',
          ),
          style: TextStyle(fontSize: 12, color: p.muted, height: 1.5),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.number = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool number;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLength: number ? null : 8,
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, required this.light});

  final String label;
  final String value;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = light ? const Color(0xFFF7EBD4) : Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: light ? const Color(0xCCF7EBD4) : p.muted))),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
