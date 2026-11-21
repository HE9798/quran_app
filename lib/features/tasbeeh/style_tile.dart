import 'package:flutter/material.dart';

import '../../core/settings/tr.dart';
import 'tasbeeh_widget.dart';

/// Settings: the look of the floating Tasbeeh button (classic or liquid glass).
class StyleTile extends StatefulWidget {
  const StyleTile({super.key});

  @override
  State<StyleTile> createState() => _StyleTileState();
}

class _StyleTileState extends State<StyleTile> {
  bool _glass = false;

  @override
  void initState() {
    super.initState();
    TasbeehWidget.glass().then((v) {
      if (mounted) setState(() => _glass = v);
    });
  }

  Future<void> _set(bool v) async {
    setState(() => _glass = v);
    await TasbeehWidget.setGlass(v);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Button style', 'شكل الزر'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(context.tr('Classic', 'كلاسيكي'))),
                ButtonSegment(
                    value: true, label: Text(context.tr('Liquid glass', 'زجاجي'))),
              ],
              selected: {_glass},
              onSelectionChanged: (s) => _set(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
