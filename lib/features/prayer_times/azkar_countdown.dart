import 'package:flutter/material.dart';

import '../../core/settings/tr.dart';
import 'prayer_controller.dart';
import 'data/prayer_models.dart';

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
    final minutes = (left.inSeconds / 60).ceil();
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final arabic = context.isArabic;
    final time = h == 0
        ? (arabic ? '$m د' : '${m}m')
        : (arabic ? '$h س $m د' : '${h}h ${m}m');

    final name = active.morning
        ? context.tr('Morning azkar', 'أذكار الصباح')
        : context.tr('Evening azkar', 'أذكار المساء');
    final endsAt = formatClock(active.end);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF), // white 15%
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              active.morning ? Icons.wb_twilight_rounded : Icons.nights_stay_rounded,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$name · ${context.tr('ends in', 'تنتهي بعد')} $time',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              endsAt,
              style: const TextStyle(
                color: Color(0xEBFFFFFF),
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
