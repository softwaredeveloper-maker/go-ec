import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:goec_intro/goec_intro.dart';

void main() => runApp(const IntroDemo());

/// How the pretend map loads on a replay.
enum _MapLoad {
  /// Ready in time, as on a normal launch: no waiting.
  normal,

  /// Ready after [_slowMap]: the bolt waits for it.
  slow,

  /// Never ready, as with no internet: the intro goes in at the 10 s limit.
  never,
}

/// How long the pretend map takes on a slow replay.
const _slowMap = Duration(seconds: 6);

/// Plays the intro into a still of the maps page (the app's first screen), then shows
/// which version played, how long it took and how smoothly.
/// Tap: replay. Long-press: replay with a slow map. Double-tap: replay with no internet.
class IntroDemo extends StatefulWidget {
  const IntroDemo({super.key});

  @override
  State<IntroDemo> createState() => _IntroDemoState();
}

class _IntroDemoState extends State<IntroDemo> with SingleTickerProviderStateMixin {
  int _run = 0;

  // Frame pacing during the intro, from vsync timestamps.
  late final Ticker _ticker = createTicker(_onFrame);
  Duration? _last;
  int _frames = 0, _late = 0;
  Duration _span = Duration.zero;
  GoEcFallback? _fallback;
  String? _result;
  _MapLoad _load = _MapLoad.normal;
  Future<void>? _mapReady; // null: no waiting

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onFrame(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    if (last == null) return;
    _frames++;
    _span = elapsed;
    if (elapsed - last > const Duration(milliseconds: 25)) _late++;
  }

  void _onFinished() {
    _ticker.stop();
    final secs = _span.inMicroseconds / 1e6;
    final fps = secs > 0 ? (_frames / secs).round() : 0;
    final took = 'Intro took ${secs.toStringAsFixed(1)} s';
    final map = switch (_load) {
      _MapLoad.normal => '',
      _MapLoad.slow => '\nWaited for a map that took ${_slowMap.inSeconds} s',
      _MapLoad.never => '\nNo internet: map never loaded, went in at the 10 s limit',
    };
    setState(() {
      _result = switch (_fallback) {
        null => 'Full animation. $took\n$fps fps average, $_late of $_frames frames late$map',
        GoEcFallback.slowPhone => 'Still logo. $took\nThis phone was too slow for the animation$map',
        GoEcFallback.reducedMotion => 'Still logo. $took\nRemove animations is on in settings$map',
      };
    });
  }

  void _replay({_MapLoad load = _MapLoad.normal}) {
    setState(() {
      _run++;
      _load = load;
      _mapReady = switch (load) {
        _MapLoad.normal => null,
        _MapLoad.slow => Future<void>.delayed(_slowMap),
        _MapLoad.never => Completer<void>().future,
      };
      _last = null;
      _frames = 0;
      _late = 0;
      _span = Duration.zero;
      _fallback = null;
      _result = null;
    });
    _ticker
      ..stop()
      ..start();
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: GoEcColors.blue,
      title: 'Go EC intro',
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, __) => builder(context)),
      home: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _replay,
        onLongPress: () => _replay(load: _MapLoad.slow),
        onDoubleTap: () => _replay(load: _MapLoad.never),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GoEcIntro(
              key: ValueKey(_run),
              ready: _mapReady,
              onFinished: _onFinished,
              onFallback: (reason) => _fallback = reason,
              child: Image.asset('assets/maps_placeholder.png', fit: BoxFit.cover, filterQuality: FilterQuality.medium),
            ),
            if (_result != null) _ResultCard(text: _result!),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xF0101418),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GoEcColors.green, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Text(
              '$text\n\nTap: replay\nLong-press: slow map (6 s)\nDouble-tap: no internet',
              textAlign: TextAlign.center,
              style: const TextStyle(color: GoEcColors.white, fontSize: 15, height: 1.45, decoration: TextDecoration.none),
            ),
          ),
        ),
      ),
    );
  }
}
