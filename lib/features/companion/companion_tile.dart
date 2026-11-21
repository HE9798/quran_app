import 'package:flutter/material.dart';

import '../../core/settings/tr.dart';
import '../tasbeeh/tasbeeh_widget.dart';
import 'companion_widget.dart';

/// Settings: switch Companion mode on or off. Turning it on asks male / female.
class CompanionTile extends StatefulWidget {
  const CompanionTile({super.key});

  @override
  State<CompanionTile> createState() => _CompanionTileState();
}

class _CompanionTileState extends State<CompanionTile> with WidgetsBindingObserver {
  bool _on = false;
  String _type = 'sheikh';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await CompanionWidget.state();
    if (mounted) setState(() {
      _on = s.enabled && s.permission;
      _type = s.type;
    });
  }

  Future<String?> _askGender() {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('Choose your companion', 'اختر رفيقك')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('sheikh'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.man_rounded, size: 32),
              title: Text(context.tr('Male', 'ذكر')),
              subtitle: Text(context.tr('The Sheikh', 'الشيخ')),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('sister'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.woman_rounded, size: 32),
              title: Text(context.tr('Female', 'أنثى')),
              subtitle: Text(context.tr('The Sister', 'الأخت')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      await CompanionWidget.stop();
      if (mounted) setState(() => _on = false);
      return;
    }

    final s = await CompanionWidget.state();
    if (!s.permission) {
      if (!mounted) return;
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('Allow display over other apps',
              'السماح بالظهور فوق التطبيقات')),
          content: Text(context.tr(
            'To show your companion on top of other apps, allow "Display over other apps" for Werd of the Day on the next screen, then come back and turn this on.',
            'لإظهار رفيقك فوق التطبيقات، اسمح بـ «الظهور فوق التطبيقات الأخرى» لتطبيق ورد اليوم في الشاشة التالية، ثم ارجع وفعّل هذا الخيار.',
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
      return;
    }

    final type = await _askGender();
    if (type == null) return;
    if (await CompanionWidget.start(type) && mounted) {
      setState(() {
        _on = true;
        _type = type;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final who = _type == 'sister'
        ? context.tr('The Sister', 'الأخت')
        : context.tr('The Sheikh', 'الشيخ');
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('Companion', 'الرفيق')),
      subtitle: Text(_on
          ? context.tr('$who is on your screen. Drag to move.',
              '$who على شاشتك. اسحب لتحريكه.')
          : context.tr('A little friend that floats on your screen',
              'رفيق صغير يظهر على شاشتك')),
      value: _on,
      onChanged: _toggle,
    );
  }
}
