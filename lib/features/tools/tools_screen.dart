import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/tr.dart';
import '../../core/theme/app_palette.dart';

/// "Tools": small helpers that are not part of the daily screens.
/// To add a tool later, add one more _ToolTile to the list.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.tr('Back', 'رجوع'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                context.tr('Tools', 'الأدوات'),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ToolTile(
          icon: Icons.explore_outlined,
          title: context.tr('Qibla', 'القبلة'),
          subtitle: context.tr('Find the direction of the Kaaba', 'اعرف اتجاه الكعبة المشرفة'),
          onTap: () => context.go('/tools/qibla'),
        ),
        const SizedBox(height: 12),
        _ToolTile(
          icon: Icons.calendar_month_outlined,
          title: context.tr('Hijri calendar', 'التقويم الهجري'),
          subtitle: context.tr('Dates and Islamic occasions', 'التواريخ والمناسبات الإسلامية'),
          onTap: () => context.go('/tools/calendar'),
        ),
        const SizedBox(height: 12),
        _ToolTile(
          icon: Icons.calculate_outlined,
          title: context.tr('Zakat calculator', 'حاسبة الزكاة'),
          subtitle: context.tr('Work out the zakat on your wealth', 'احسب زكاة مالك'),
          onTap: () => context.go('/tools/zakat'),
        ),
        const SizedBox(height: 12),
        _ToolTile(
          icon: Icons.mosque_outlined,
          title: context.tr('Hajj & Umrah', 'مناسك الحج والعمرة'),
          subtitle: context.tr('The rites step by step, with their supplications',
              'المناسك خطوة بخطوة مع أذكارها'),
          onTap: () => context.go('/tools/manasik'),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            context.tr('More tools will appear here', 'ستظهر أدوات أخرى هنا'),
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: p.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: p.onPrimarySoft, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: p.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
