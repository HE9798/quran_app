import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

import '../../core/settings/tr.dart';
import 'prayer_controller.dart';

/// Line for the green prayer cards: how long is left before the morning /
/// evening azkar window closes. Shows nothing outside those windows.
///   morning: Fajr -> Sunrise      evening: Asr -> Maghrib
/// The controller already refreshes every 20 seconds, so this stays current.
class AzkarCountdown extends StatelessWidget {
  const AzkarCountdown({super.key, required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.activeAzkar;
    if (active == null) return const SizedBox.shrink();

    final left = active.end.difference(DateTime.now());
    final time = context.span(left);
    final name = active.morning
        ? context.tr('Morning azkar', 'أذكار الصباح')
        : context.tr('Evening azkar', 'أذكار المساء');
    final endsAt = context.clock(active.end);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x26F7EBD4), // white 15%
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              active.morning ? Icons.wb_twilight_rounded : Icons.nights_stay_rounded,
              size: 18,
              color: AppColors.cream,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$name · ${context.tr('ends in', 'تنتهي بعد')} $time',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              endsAt,
              style: const TextStyle(
                color: Color(0xEBF7EBD4),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
