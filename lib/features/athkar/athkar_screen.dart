import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'data/athkar_models.dart';
import 'data/athkar_progress_store.dart';
import 'data/athkar_repository.dart';

/// Morning and evening athkar. Tap the circle to count, the next dhikr
/// opens by itself when you reach the number of repeats.
class AthkarScreen extends StatefulWidget {
  const AthkarScreen({super.key});

  @override
  State<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends State<AthkarScreen> {
  late Future<Map<AthkarSet, List<Dhikr>>> _future = _start();

  Future<Map<AthkarSet, List<Dhikr>>> _start() async {
    await AthkarProgressStore.instance.load();
    return AthkarRepository.instance.loadAll();
  }

  void _retry() => setState(() => _future = _start());

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<Map<AthkarSet, List<Dhikr>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return _AthkarBody(data: snapshot.data!);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Title(subtitle: ''),
            Expanded(
              child: snapshot.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded,
                                size: 44, color: p.muted),
                            const SizedBox(height: 12),
                            const Text(
                              "Couldn't load the athkar",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check your internet connection and try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: p.muted),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _retry,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.subtitle, this.onReset});

  final String subtitle;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Athkar',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: p.muted),
                ),
              ],
            ),
          ),
          if (onReset != null)
            IconButton(
              tooltip: 'Start again',
              onPressed: onReset,
              style: IconButton.styleFrom(fixedSize: const Size(44, 44)),
              icon: Icon(Icons.refresh_rounded, color: p.muted),
            ),
        ],
      ),
    );
  }
}

class _AthkarBody extends StatefulWidget {
  const _AthkarBody({required this.data});

  final Map<AthkarSet, List<Dhikr>> data;

  @override
  State<_AthkarBody> createState() => _AthkarBodyState();
}

class _AthkarBodyState extends State<_AthkarBody>
    with SingleTickerProviderStateMixin {
  // Morning until mid-afternoon, evening after that.
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: DateTime.now().hour >= 15 ? 1 : 0,
  )..addListener(() => setState(() {}));

  final _progress = AthkarProgressStore.instance;

  AthkarSet get _set => AthkarSet.values[_tabs.index];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final set = _set;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start ${set.label.toLowerCase()} athkar again?'),
        content: const Text("Today's counts for this list will be cleared."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start again'),
          ),
        ],
      ),
    );
    if (ok == true) _progress.reset(set);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListenableBuilder(
          listenable: _progress,
          builder: (context, _) {
            final items = widget.data[_set]!;
            final counts = _progress.countsFor(_set, items.length);
            var done = 0;
            for (var i = 0; i < items.length; i++) {
              if (counts[i] >= items[i].repeat) done++;
            }
            return _Title(
              subtitle: '${_set.label} · $done of ${items.length} completed',
              onReset: _confirmReset,
            );
          },
        ),
        Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: scheme.onPrimary,
            unselectedLabelColor: scheme.onSurface,
            labelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            splashBorderRadius: BorderRadius.circular(12),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            tabs: const [
              Tab(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Morning'),
                  ],
                ),
              ),
              Tab(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dark_mode_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Evening'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (final set in AthkarSet.values)
                _SetView(key: ValueKey(set), set: set, items: widget.data[set]!),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- one list

class _SetView extends StatefulWidget {
  const _SetView({super.key, required this.set, required this.items});

  final AthkarSet set;
  final List<Dhikr> items;

  @override
  State<_SetView> createState() => _SetViewState();
}

class _SetViewState extends State<_SetView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _progress = AthkarProgressStore.instance;

  /// The dhikr the user jumped to from "Up next" (null = first unfinished).
  int? _focus;

  List<Dhikr> get _items => widget.items;

  bool _isDone(List<int> counts, int i) => counts[i] >= _items[i].repeat;

  /// First unfinished dhikr after [after] (wrapping around), or null.
  int? _nextUnfinished(List<int> counts, {int after = -1}) {
    for (var step = 1; step <= _items.length; step++) {
      final i = (after + step) % _items.length;
      if (!_isDone(counts, i)) return i;
    }
    return null;
  }

  int? _current(List<int> counts) {
    final focus = _focus;
    if (focus != null && focus < _items.length && !_isDone(counts, focus)) {
      return focus;
    }
    return _nextUnfinished(counts);
  }

  void _tap(int index) {
    final count = _progress.increment(widget.set, index, _items.length);
    if (count >= _items[index].repeat) {
      HapticFeedback.mediumImpact();
      final counts = _progress.countsFor(widget.set, _items.length);
      setState(() => _focus = _nextUnfinished(counts, after: index));
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: _progress,
      builder: (context, _) {
        final counts = _progress.countsFor(widget.set, _items.length);
        final current = _current(counts);

        // the next three unfinished ones after the current dhikr
        final upNext = <int>[];
        if (current != null) {
          for (var step = 1; step < _items.length && upNext.length < 3; step++) {
            final i = (current + step) % _items.length;
            if (!_isDone(counts, i)) upNext.add(i);
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: current == null
                  ? _AllDone(
                      key: const ValueKey('done'),
                      set: widget.set,
                      onAgain: () {
                        _progress.reset(widget.set);
                        setState(() => _focus = null);
                      },
                    )
                  : _DhikrCard(
                      key: ValueKey(current),
                      dhikr: _items[current],
                      position: current + 1,
                      total: _items.length,
                      count: counts[current],
                      onTap: () => _tap(current),
                    ),
            ),
            if (upNext.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Up next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final i in upNext) ...[
                _UpNextTile(
                  number: i + 1,
                  dhikr: _items[i],
                  onTap: () => setState(() => _focus = i),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    super.key,
    required this.dhikr,
    required this.position,
    required this.total,
    required this.count,
    required this.onTap,
  });

  final Dhikr dhikr;
  final int position;
  final int total;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // long athkar (Ayat al-Kursi, ...) get a smaller font
    final length = dhikr.text.length;
    final fontSize = length > 450 ? 20.0 : (length > 220 ? 24.0 : 30.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Pill('$position of $total'),
              _Pill(dhikr.repeat > 1 ? 'Repeat × ${dhikr.repeat}' : 'Once'),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: Text(
              dhikr.text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTheme.arabic(size: fontSize, height: 1.9),
            ),
          ),
          if (dhikr.virtue != null || dhikr.source != null) ...[
            const SizedBox(height: 6),
            if (dhikr.virtue != null)
              Text(
                dhikr.virtue!,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.arabic(size: 16, height: 1.7, color: p.muted),
              ),
            if (dhikr.source != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  dhikr.source!,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.arabic(size: 14, height: 1.5, color: p.muted),
                ),
              ),
          ],
          const SizedBox(height: 16),
          _CounterButton(
            count: count,
            total: dhikr.repeat,
            onTap: onTap,
          ),
          const SizedBox(height: 10),
          Text(
            'Tap the circle to count',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.onPrimarySoft,
        ),
      ),
    );
  }
}

/// The big round counter with its progress ring.
class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.count,
    required this.total,
    required this.onTap,
  });

  final int count;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Count dhikr, $count of $total',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 148,
          height: 148,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                ),
              ),
              SizedBox(
                width: 148,
                height: 148,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (count / total).clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: p.border,
                    color: scheme.primary,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'of $total',
                    style: TextStyle(fontSize: 13, color: p.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpNextTile extends StatelessWidget {
  const _UpNextTile({
    required this.number,
    required this.dhikr,
    required this.onTap,
  });

  final int number;
  final Dhikr dhikr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: p.border),
    );
    return Material(
      color: p.surface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.onPrimarySoft,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dhikr.title,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.arabic(size: 18, height: 1.5).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '×${dhikr.repeat}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone({super.key, required this.set, required this.onAgain});

  final AthkarSet set;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 40, color: scheme.onPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            'تقبل الله منا ومنكم',
            textDirection: TextDirection.rtl,
            style: AppTheme.arabic(size: 28, height: 1.6),
          ),
          const SizedBox(height: 4),
          Text(
            "You've completed the ${set.label.toLowerCase()} athkar",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAgain,
            child: const Text('Start again'),
          ),
        ],
      ),
    );
  }
}
