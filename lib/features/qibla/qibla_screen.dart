import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../prayer_times/prayer_controller.dart';
import '../prayer_times/data/location_service.dart';
import 'qibla_math.dart';

/// Live Qibla compass. The dial turns with the phone, so the Kaaba marker
/// ends up at the top when you face Makkah.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  final _controller = PrayerController.instance;

  /// Smoothed compass heading in degrees (0 = north). Null = no sensor yet.
  final _heading = ValueNotifier<double?>(null);
  StreamSubscription<CompassEvent>? _subscription;
  bool _noSensor = false;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _controller.start(); // makes sure we have a location
    final stream = FlutterCompass.events;
    if (stream == null) {
      _noSensor = true;
    } else {
      _subscription = stream.listen(_onCompass, onError: (_) {
        if (mounted) setState(() => _noSensor = true);
      });
    }
  }

  void _onCompass(CompassEvent event) {
    final raw = event.heading;
    if (raw == null) {
      if (mounted && !_noSensor) setState(() => _noSensor = true);
      return;
    }
    final value = (raw % 360 + 360) % 360;
    final old = _heading.value;
    // Smooth the jitter. Works around 359° -> 0° because it uses the
    // shortest angle between the two readings.
    _heading.value =
        old == null ? value : (old + 0.25 * angleDiff(value, old) + 360) % 360;
    _buzzWhenAligned();
  }

  void _buzzWhenAligned() {
    final location = _controller.location;
    final heading = _heading.value;
    if (location == null || heading == null) return;
    final bearing = qiblaBearing(location.lat, location.lng);
    final aligned = angleDiff(heading, bearing).abs() <= 3;
    if (aligned && !_wasAligned) HapticFeedback.mediumImpact();
    _wasAligned = aligned;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _heading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final location = _controller.location;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/prayer'),
                    style: IconButton.styleFrom(
                      backgroundColor: p.surface,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      fixedSize: const Size(44, 44),
                      side: BorderSide(color: p.border),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  ),
                  const Text(
                    'Qibla',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 44, height: 44),
                ],
              ),
            ),
            Expanded(
              child: location == null
                  ? _NoLocation(controller: _controller)
                  : _Body(
                      location: location,
                      heading: _heading,
                      noSensor: _noSensor,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NoLocation extends StatelessWidget {
  const _NoLocation({required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 44, color: p.muted),
            const SizedBox(height: 12),
            const Text(
              'We need your location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'The Qibla direction depends on where you are.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => controller.load(refreshLocation: true),
              child: const Text('Allow location'),
            ),
            if (controller.locationProblem == LocationProblem.deniedForever ||
                controller.locationProblem == LocationProblem.serviceOff)
              TextButton(
                onPressed: () => LocationService.instance
                    .openSettings(controller.locationProblem!),
                child: const Text('Open settings'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.location,
    required this.heading,
    required this.noSensor,
  });

  final UserLocation location;
  final ValueNotifier<double?> heading;
  final bool noSensor;

  static String _km(double km) {
    final digits = km.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '$buffer km';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bearing = qiblaBearing(location.lat, location.lng);
    final distance = distanceToKaabaKm(location.lat, location.lng);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Center(
          child: ValueListenableBuilder<double?>(
            valueListenable: heading,
            builder: (context, value, _) {
              final aligned =
                  value != null && angleDiff(value, bearing).abs() <= 3;
              return _StatusChip(
                aligned: aligned,
                noSensor: noSensor,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ValueListenableBuilder<double?>(
            valueListenable: heading,
            builder: (context, value, _) {
              return _Compass(
                bearing: bearing,
                heading: noSensor ? null : value,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text(
                '${bearing.round()}°',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${compassName(bearing)} · towards Makkah',
                style: TextStyle(fontSize: 15, color: p.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Distance to the Kaaba',
                value: _km(distance),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Your location',
                value: location.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.primarySoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline_rounded,
                    size: 22, color: p.onPrimarySoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  noSensor
                      ? "This phone has no compass sensor. Use a compass or "
                          "a map to face ${bearing.round()}° from north."
                      : 'Hold your phone flat and away from metal objects. '
                          'If the marker drifts, move your phone in a '
                          'figure 8 to calibrate.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: p.onPrimarySoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.aligned, required this.noSensor});

  final bool aligned;
  final bool noSensor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    final (text, icon) = noSensor
        ? ('No compass sensor', Icons.sensors_off_outlined)
        : aligned
            ? ("You're facing the Qibla", Icons.check_rounded)
            : ('Turn until the Kaaba is at the top', Icons.rotate_right_rounded);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: aligned ? scheme.primary : p.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16, color: aligned ? scheme.onPrimary : p.onPrimarySoft),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: aligned ? scheme.onPrimary : p.onPrimarySoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: p.muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- compass

/// The dial. [heading] is where the phone points (null = no sensor, the dial
/// then stays with north at the top).
class _Compass extends StatelessWidget {
  const _Compass({required this.bearing, required this.heading});

  final double bearing;
  final double? heading;

  static const double size = 300;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final turn = -(heading ?? 0) * math.pi / 180;

    return Semantics(
      label: 'Qibla compass. The Kaaba is ${bearing.round()} degrees, '
          '${compassName(bearing)} of north.',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: turn,
              child: CustomPaint(
                size: const Size(size, size),
                painter: _DialPainter(
                  bearing: bearing,
                  surface: p.surface,
                  border: p.border,
                  muted: p.muted,
                  text: scheme.onSurface,
                  accent: scheme.primary,
                  onAccent: scheme.onPrimary,
                ),
              ),
            ),
            // fixed marker: where the phone points
            Positioned(
              top: 0,
              child: CustomPaint(
                size: const Size(14, 12),
                painter: _TopMarkerPainter(scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopMarkerPainter extends CustomPainter {
  const _TopMarkerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TopMarkerPainter old) => old.color != color;
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.bearing,
    required this.surface,
    required this.border,
    required this.muted,
    required this.text,
    required this.accent,
    required this.onAccent,
  });

  final double bearing;
  final Color surface;
  final Color border;
  final Color muted;
  final Color text;
  final Color accent;
  final Color onAccent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final k = size.width / 300; // the design is drawn at 300 px

    // dial
    canvas.drawCircle(c, 136 * k, Paint()..color = surface);
    canvas.drawCircle(
      c,
      136 * k,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = border,
    );
    canvas.drawCircle(
      c,
      76 * k,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = border,
    );

    // ticks every 30 degrees, longer at N / E / S / W
    final tick = Paint()
      ..color = muted
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 - math.pi / 2;
      final long = i % 3 == 0;
      final from = 130 * k;
      final to = (long ? 114 : 120) * k;
      canvas.drawLine(
        c + Offset(math.cos(angle), math.sin(angle)) * from,
        c + Offset(math.cos(angle), math.sin(angle)) * to,
        tick,
      );
    }

    // N E S W
    _letter(canvas, c, 'N', 0, 88 * k, accent, FontWeight.w800, 17);
    _letter(canvas, c, 'E', 90, 94 * k, text, FontWeight.w700, 15);
    _letter(canvas, c, 'S', 180, 94 * k, text, FontWeight.w700, 15);
    _letter(canvas, c, 'W', 270, 94 * k, text, FontWeight.w700, 15);

    // the Kaaba marker, at the Qibla bearing
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(bearing * math.pi / 180);
    canvas.drawLine(
      Offset.zero,
      Offset(0, -76 * k),
      Paint()
        ..color = accent
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(0, -96 * k), 20 * k, Paint()..color = accent);
    final kaaba = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -96 * k), width: 18 * k, height: 18 * k),
      Radius.circular(3 * k),
    );
    canvas.drawRRect(kaaba, Paint()..color = onAccent);
    canvas.drawLine(
      Offset(-9 * k, -102 * k),
      Offset(9 * k, -102 * k),
      Paint()
        ..color = accent
        ..strokeWidth = 2.5,
    );
    canvas.restore();

    // centre hub
    canvas.drawCircle(c, 11 * k, Paint()..color = accent);
    canvas.drawCircle(c, 4 * k, Paint()..color = onAccent);
  }

  /// Draws a letter [radius] away from the centre at [degrees] on the dial.
  void _letter(Canvas canvas, Offset c, String letter, double degrees,
      double radius, Color color, FontWeight weight, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: color,
          fontWeight: weight,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final angle = degrees * math.pi / 180 - math.pi / 2;
    final center = c + Offset(math.cos(angle), math.sin(angle)) * radius;

    // keep the letter upright on the dial (rotated with it)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(degrees * math.pi / 180);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.bearing != bearing ||
      old.surface != surface ||
      old.accent != accent ||
      old.text != text;
}
