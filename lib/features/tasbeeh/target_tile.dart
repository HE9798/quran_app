import 'package:material_ui/material_ui.dart';

import '../../core/settings/tr.dart';
import 'tasbeeh_widget.dart';

/// Settings: the number at which the floating button's slider is full.
class TargetTile extends StatefulWidget {
  const TargetTile({super.key});

  @override
  State<TargetTile> createState() => _TargetTileState();
}

class _TargetTileState extends State<TargetTile> {
  static const _presets = [10, 33, 100, 1000];
  int _target = 100;

  @override
  void initState() {
    super.initState();
    TasbeehWidget.target().then((v) {
      if (mounted) setState(() => _target = v);
    });
  }

  Future<void> _set(int v) async {
    setState(() => _target = v);
    await TasbeehWidget.setTarget(v);
  }

  Future<void> _custom() async {
    final controller = TextEditingController(text: '$_target');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Your own number', 'رقمك الخاص')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.tr('e.g. 50', 'مثال: 50'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              Navigator.of(context).pop(n != null && n > 0 ? n : null);
            },
            child: Text(context.tr('Save', 'حفظ')),
          ),
        ],
      ),
    );
    if (value != null) await _set(value);
  }

  @override
  Widget build(BuildContext context) {
    final custom = !_presets.contains(_target);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Slider fills at', 'يمتلئ الشريط عند'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            context.tr('When it is full, the x on top goes up by one',
                'عند امتلائه يزيد الرقم x بمقدار واحد'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final n in _presets)
                ChoiceChip(
                  label: Text(context.n(n)),
                  selected: _target == n,
                  onSelected: (_) => _set(n),
                ),
              ChoiceChip(
                label: Text(custom
                    ? context.n(_target)
                    : context.tr('Custom', 'مخصص')),
                selected: custom,
                onSelected: (_) => _custom(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
