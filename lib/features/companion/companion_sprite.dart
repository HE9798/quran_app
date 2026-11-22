import 'package:flutter/material.dart';

/// The companion drawn in the app: body + head, and the head bobs down a
/// little and back (the same idle animation as on the phone screen).
///
/// Needs these pictures (copies of the ones in the Android res folder):
///   assets/companion/sheikh_body.png, sheikh_head.png,
///   assets/companion/sister_body.png, sister_head.png
class CompanionSprite extends StatefulWidget {
  const CompanionSprite({super.key, required this.type, required this.height, this.bob = true});

  /// "sheikh" or "sister"
  final String type;
  final double height;
  final bool bob;

  @override
  State<CompanionSprite> createState() => _CompanionSpriteState();
}

class _CompanionSpriteState extends State<CompanionSprite> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.bob) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.type == 'sister' ? 'sister' : 'sheikh';
    final h = widget.height;
    // In Arabic (right-to-left) the character sits on the right side of the
    // screen, so it is mirrored to face inward, like the floating one.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Transform.flip(
      flipX: rtl,
      child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // two steps, like pixel animation: up for half a second, down for half
        final down = widget.bob && _c.value >= 0.5;
        return SizedBox(
          height: h + h * 0.024,
          child: Stack(
            children: [
              Image.asset('assets/companion/${name}_body.png',
                  height: h, filterQuality: FilterQuality.none),
              Transform.translate(
                offset: Offset(0, down ? h * 0.024 : 0),
                child: Image.asset('assets/companion/${name}_head.png',
                    height: h, filterQuality: FilterQuality.none),
              ),
            ],
          ),
        );
      },
    ),
    );
  }
}
