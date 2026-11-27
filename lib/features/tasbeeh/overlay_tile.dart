import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/settings/tr.dart';
import 'tasbeeh_widget.dart';

/// Settings switch for the floating Tasbeeh button.
class OverlayTile extends StatefulWidget {
  const OverlayTile({super.key});

  @override
  State<OverlayTile> createState() => _OverlayTileState();
}

class _OverlayTileState extends State<OverlayTile> with WidgetsBindingObserver {
  bool _on = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    // the button can be closed with the fire while this page is open: keep
    // the switch in step with it
    _poll = Timer.periodic(const Duration(milliseconds: 700), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the phone's settings page, or the button was dragged away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await TasbeehWidget.overlayState();
    if (mounted) setState(() => _on = s.enabled && s.permission);
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      await TasbeehWidget.stopOverlay();
      if (mounted) setState(() => _on = false);
      return;
    }
    if (await TasbeehWidget.startOverlay()) {
      if (mounted) setState(() => _on = true);
      return;
    }
    // "Display over other apps" is not allowed yet: explain, then open it
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Allow display over other apps',
            'السماح بالظهور فوق التطبيقات')),
        content: Text(context.tr(
          'To keep the button on top of other apps, allow "Display over other apps" for Werd of the Day on the next screen, then come back and turn this on.',
          'لإبقاء الزر فوق التطبيقات، اسمح بـ «الظهور فوق التطبيقات الأخرى» لتطبيق ورد اليوم في الشاشة التالية، ثم ارجع وفعّل هذا الخيار.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Open settings', 'فتح الإعدادات')),
          ),
        ],
      ),
    );
    if (open == true) await TasbeehWidget.openOverlayPermission();
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('Floating Tasbeeh button', 'زر التسبيح العائم')),
      subtitle: Text(context.tr(
          'Stays on top of other apps.',
          'يبقى فوق التطبيقات.')),
      value: _on,
      onChanged: _toggle,
    );
  }
}
