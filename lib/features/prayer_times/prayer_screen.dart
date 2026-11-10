import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_view.dart';
import '../home/home_screen.dart' show StarPatternPainter;
import '../qibla/qibla_math.dart';
import 'data/location_service.dart';
import 'data/prayer_models.dart';
import 'prayer_controller.dart';

/// Prayer times for today at the phone's location, with a reminder switch
/// for every prayer and a shortcut to the Qibla compass.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen>
    with WidgetsBindingObserver {
  final _controller = PrayerController.instance;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background (or from the settings screen): refresh.
    if (state == AppLifecycleState.resumed) {
      _controller.start();
      if (_controller.schedule == null || _controller.needsRefresh) {
        _controller.load();
      }
    }
  }

  static String time12(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _countdown(Duration d) {
    final minutes = (d.inSeconds / 60).ceil();
    if (minutes <= 0) return 'now';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return 'in ${m}m';
    return 'in ${h}h ${m}m';
  }

  Future<void> _toggle(Prayer prayer, bool on) async {
    final ok = await _controller.setAlert(prayer, on);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text(
            'Notifications are blocked. Allow them in the phone settings '
            'to get prayer reminders.',
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;

        Widget body;
        if (c.schedule == null && c.loading) {
          body = const _Loading();
        } else if (c.locationProblem != null) {
          body = _LocationProblemView(
            problem: c.locationProblem!,
            onRetry: () => c.load(refreshLocation: true),
          );
        } else if (c.schedule == null) {
          body = ErrorView(
            title: "Couldn't load prayer times",
            onRetry: () => c.load(),
          );
        } else {
          body = _Content(
            controller: c,
            onToggle: _toggle,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              dateLine: _dateLine(c),
              city: c.location?.city,
              busy: c.loading,
              onCityTap: () => c.load(refreshLocation: true),
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }

  String _dateLine(PrayerController c) {
    final now = c.now ?? DateTime.now();
    final date =
        '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
    final hijri = c.today?.hijri ?? '';
    return hijri.isEmpty ? date : '$date · $hijri';
  }
}

// ------------------------------------------------------------------ header

class _Header extends StatelessWidget {
  const _Header({
    required this.dateLine,
    required this.city,
    required this.busy,
    required this.onCityTap,
  });

  final String dateLine;
  final String? city;
  final bool busy;
  final VoidCallback onCityTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prayer times',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Update my location',
            child: Material(
              color: p.primarySoft,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: busy ? null : onCityTap,
                child: Container(
                  height: 40,
                  constraints: const BoxConstraints(maxWidth: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busy)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onPrimarySoft,
                          ),
                        )
                      else
                        Icon(Icons.location_on_outlined,
                            size: 17, color: p.onPrimarySoft),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          city ?? 'Locating',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.onPrimarySoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ states

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Finding your location…',
            style: TextStyle(color: context.palette.muted),
          ),
        ],
      ),
    );
  }
}

class _LocationProblemView extends StatelessWidget {
  const _LocationProblemView({required this.problem, required this.onRetry});

  final LocationProblem problem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (title, message, needsSettings) = switch (problem) {
      LocationProblem.serviceOff => (
          'Location is turned off',
          'Switch on location so we can calculate prayer times for where you are.',
          true,
        ),
      LocationProblem.denied => (
          'Location permission needed',
          'Prayer times and Qibla depend on where you are. Allow location access to continue.',
          false,
        ),
      LocationProblem.deniedForever => (
          'Location permission is blocked',
          'Allow location for this app in the phone settings, then come back.',
          true,
        ),
      LocationProblem.unavailable => (
          "Couldn't find your location",
          'Make sure you are not in airplane mode, then try again.',
          false,
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 44, color: p.muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (needsSettings)
              FilledButton(
                onPressed: () => LocationService.instance.openSettings(problem),
                child: const Text('Open settings'),
              ),
            if (needsSettings) const SizedBox(height: 8),
            needsSettings
                ? TextButton(onPressed: onRetry, child: const Text('Try again'))
                : FilledButton(
                    onPressed: onRetry,
                    child: Text(problem == LocationProblem.denied
                        ? 'Allow location'
                        : 'Try again'),
                  ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- content

class _Content extends StatelessWidget {
  const _Content({required this.controller, required this.onToggle});

  final PrayerController controller;
  final Future<void> Function(Prayer prayer, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final today = c.today;
    final next = c.next;
    final location = c.location;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (next != null) _NextCard(controller: c, next: next),
        const SizedBox(height: 14),
        if (today != null)
          for (final prayer in Prayer.values)
            _PrayerRow(
              prayer: prayer,
              time: today.times[prayer]!,
              isNext: next != null &&
                  next.prayer == prayer &&
                  next.time == today.times[prayer],
              on: c.isAlertOn(prayer),
              onChanged: (value) => onToggle(prayer, value),
            ),
        const SizedBox(height: 10),
        if (location != null) _QiblaCard(location: location),
      ],
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.controller, required this.next});

  final PrayerController controller;
  final NextPrayer next;

  static const _onHeroSoft = Color(0xEBFFFFFF); // white 92%
  static const _heroGreenText = Color(0xFF0B6B49);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final remaining = next.time.difference(DateTime.now());
    final previous = next.previous;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -44,
            top: -50,
            child: SizedBox(
              width: 190,
              height: 190,
              child: CustomPaint(painter: StarPatternPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Next prayer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _onHeroSoft,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${next.prayer.english} · '
                              '${_PrayerScreenState.time12(next.time)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _PrayerScreenState._countdown(remaining),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _heroGreenText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: controller.progressOf(next),
                      minHeight: 6,
                      backgroundColor: const Color(0x4DFFFFFF), // white 30%
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        previous == null
                            ? ''
                            : '${previous.prayer.english} '
                                '${_PrayerScreenState.time12(previous.time)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _onHeroSoft,
                        ),
                      ),
                      Text(
                        '${next.prayer.english} '
                        '${_PrayerScreenState.time12(next.time)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _onHeroSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayer,
    required this.time,
    required this.isNext,
    required this.on,
    required this.onChanged,
  });

  final Prayer prayer;
  final DateTime time;
  final bool isNext;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final isSunrise = !prayer.isPrayer;

    final nameColor = isNext
        ? p.onPrimarySoft
        : isSunrise
            ? p.muted
            : scheme.onSurface;
    final weight = isNext
        ? FontWeight.w800
        : isSunrise
            ? FontWeight.w600
            : FontWeight.w700;

    return Container(
      height: 56,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: isNext ? p.primarySoft : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  prayer.english,
                  style: TextStyle(
                      fontSize: 16, fontWeight: weight, color: nameColor),
                ),
                const SizedBox(width: 10),
                Text(
                  prayer.arabic,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.arabic(
                    size: 17,
                    height: 1.2,
                    color: isNext ? p.onPrimarySoft : p.muted,
                  ),
                ),
                if (isNext) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _PrayerScreenState.time12(time),
            style: TextStyle(
              fontSize: 15,
              fontWeight: weight,
              color: nameColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          _AlertSwitch(
            label: '${prayer.english} reminder',
            value: on,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// The reminder switch from the design: a filled green pill when on, an
/// outlined grey pill when off. The tap area is 52x44.
class _AlertSwitch extends StatelessWidget {
  const _AlertSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 52,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 40,
              height: 24,
              decoration: BoxDecoration(
                color: value ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: value ? null : Border.all(color: p.muted, width: 1.5),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.all(value ? 3 : 4.5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: value ? 18 : 15,
                    height: value ? 18 : 15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? scheme.onPrimary : p.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QiblaCard extends StatelessWidget {
  const _QiblaCard({required this.location});

  final UserLocation location;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bearing = qiblaBearing(location.lat, location.lng);

    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/prayer/qibla'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.explore_outlined,
                    size: 24, color: p.onPrimarySoft),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Qibla direction',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${bearing.round()}° · ${compassName(bearing)}',
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
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
