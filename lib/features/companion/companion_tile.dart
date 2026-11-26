import 'package:material_ui/material_ui.dart';

import '../../core/settings/tr.dart';
import '../tasbeeh/tasbeeh_widget.dart';
import 'companion_widget.dart';
import 'data/companion_store.dart';

/// Settings: switch Companion mode on or off. Turning it on asks male / female.
class CompanionTile extends StatefulWidget {
  const CompanionTile({super.key});

  @override
  State<CompanionTile> createState() => _CompanionTileState();
}

class _CompanionTileState extends State<CompanionTile> with WidgetsBindingObserver {
  bool _on = false;
  bool _lock = true; //     companion on the lock screen
  bool _lockAllowed = true; // Android 14+: full-screen notifications allowed

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
    final lock = await CompanionWidget.lockState();
    if (mounted) {
      setState(() {
        _on = s.enabled && s.permission;
        _lock = lock.enabled;
        _lockAllowed = lock.allowed;
      });
    }
  }

  Future<void> _setLock(bool on) async {
    await CompanionWidget.setLockScreen(on);
    if (on) await CompanionStore.instance.pushStrings(); // names on the buttons
    if (mounted) setState(() => _lock = on);
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
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('sister'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.woman_rounded, size: 32),
              title: Text(context.tr('Female', 'أنثى')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      await CompanionWidget.stop();
      await CompanionStore.instance.setActive(false);
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

    final store = CompanionStore.instance;
    String? type;
    String? newName;
    if (!store.chosen) {
      // asked only the first time, and again after a reset
      type = await _askGender();
      if (type == null || !mounted) return;
      newName = await _askName();
      if (newName == null) return;
    }
    final useType = type ?? store.type;
    if (await CompanionWidget.start(useType)) {
      if (type != null) await store.setIdentity(type, newName ?? '');
      await store.setActive(true, companion: useType);
      if (mounted) {
        setState(() => _on = true);
      }
    }
  }

  Future<String?> _askName() {
    return showDialog<String>(context: context, builder: (_) => const _NameDialog());
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Reset companion?', 'إعادة ضبط الرفيق؟')),
        content: Text(context.tr(
          'Your companion will be turned off and everything is cleared: coins, streak and days together. Next time you turn it on, you will choose male or female and a name again.',
          'سيتم إيقاف الرفيق ومسح كل شيء: العملات والأيام المتتالية وأيام الرفقة. وعند تفعيله مرة أخرى ستختار ذكر أو أنثى والاسم من جديد.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Reset', 'إعادة ضبط')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CompanionWidget.stop();
    await CompanionStore.instance.resetIdentity();
    if (mounted) setState(() => _on = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = CompanionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Companion', 'الرفيق')),
            subtitle: Text(_on
                ? context.tr('${store.displayName(false)} is on your screen. Drag to move.',
                    '${store.displayName(true)} على شاشتك. اسحب لتحريكه.')
                : context.tr('A little friend that floats on your screen',
                    'رفيق صغير يظهر على شاشتك')),
            value: _on,
            onChanged: _toggle,
          ),
          if (_on) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Show on the lock screen', 'الظهور على شاشة القفل')),
              subtitle: Text(context.tr(
                'When it has something to say while your phone is locked, it appears full screen',
                'عندما يكون لديه ما يقوله وهاتفك مقفل، يظهر على الشاشة كاملة',
              )),
              value: _lock,
              onChanged: _setLock,
            ),
            if (_lock && !_lockAllowed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error),
                title: Text(context.tr('Allow full-screen notifications',
                    'السماح بالإشعارات بملء الشاشة')),
                subtitle: Text(context.tr(
                  'Needed to appear over the lock screen. Without it you get a normal notification.',
                  'مطلوب للظهور فوق شاشة القفل. بدونه يصلك إشعار عادي.',
                )),
                onTap: CompanionWidget.openLockPermission,
              ),
          ],
          if (store.chosen)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restart_alt_rounded),
              title: Text(context.tr('Reset companion', 'إعادة ضبط الرفيق')),
              subtitle: Text(context.tr('Start over: choice, name and progress',
                  'البدء من جديد: الاختيار والاسم والتقدم')),
              onTap: _reset,
            ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Name your companion', 'سمِّ رفيقك')),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: 20,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: context.tr('Any name you like', 'أي اسم تحبه')),
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.of(context).pop(v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel', 'إلغاء')),
        ),
        FilledButton(
          onPressed: _c.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_c.text.trim()),
          child: Text(context.tr('Start', 'ابدأ')),
        ),
      ],
    );
  }
}
