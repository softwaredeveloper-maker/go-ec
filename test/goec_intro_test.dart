import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goec_intro/goec_intro.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduceMotion),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

/// Pumps 50 ms frames until [done] or [limitMs]; fails on any paint error. Returns the ms pumped.
Future<int> _pumpUntil(WidgetTester tester, bool Function() done, {int limitMs = 20000}) async {
  var ms = 0;
  while (!done() && ms < limitMs) {
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull, reason: 'paint failed at $ms ms');
    ms += 50;
  }
  return ms;
}

/// Pumps exactly [ms] in 50 ms frames.
Future<void> _pumpFor(WidgetTester tester, int ms) => _pumpUntil(tester, () => false, limitMs: ms);

void main() {
  testWidgets('plays through every phase and hands over to the child', (tester) async {
    var finished = false;
    await tester.pumpWidget(_host(GoEcIntro(onFinished: () => finished = true, child: const GoEcIntroPlaceholder())));

    // Step through the whole timeline so every branch of the painter runs.
    for (var ms = 0; ms <= 3800; ms += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'paint failed at $ms ms');
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(finished, isTrue);
    expect(find.byType(CustomPaint), findsNothing, reason: 'intro layer should be gone');

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Power of smooth Animations'), findsOneWidget);
  });

  testWidgets('reduced motion shows the static splash, then the child', (tester) async {
    var finished = false;
    await tester.pumpWidget(_host(
      GoEcIntro(onFinished: () => finished = true, child: const GoEcIntroPlaceholder()),
      reduceMotion: true,
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(finished, isFalse);
    // Hold (900 ms) runs out, then a 250 ms fade to the child.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(finished, isTrue);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a phone that misses frames gets the static splash', (tester) async {
    GoEcIntro.debugCheckFrames = true;
    addTearDown(() => GoEcIntro.debugCheckFrames = false);
    var finished = false;
    await tester.pumpWidget(_host(GoEcIntro(onFinished: () => finished = true, child: const GoEcIntroPlaceholder())));

    // 40 ms frames (25 fps): decided after 12 frames, then fade in, hold, fade out.
    var ms = 0;
    while (!finished && ms < 3000) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull);
      ms += 40;
    }
    expect(finished, isTrue);
    // Static path: 12 frames + 250 fade + 900 hold + 250 fade, well before the 3.8 s animation would end.
    expect(ms, lessThan(2000));
  });

  testWidgets('a phone that keeps up plays the full animation', (tester) async {
    GoEcIntro.debugCheckFrames = true;
    addTearDown(() => GoEcIntro.debugCheckFrames = false);
    var finished = false;
    await tester.pumpWidget(_host(GoEcIntro(onFinished: () => finished = true, child: const GoEcIntroPlaceholder())));
    var ms = 0;
    while (!finished && ms < 5000) {
      await tester.pump(const Duration(microseconds: 16667));
      ms += 17;
    }
    expect(ms, greaterThan(3700));
  });

  group('waiting for ready', () {
    testWidgets('ready before the bolt: plays straight through', (tester) async {
      final ready = Completer<void>();
      var finished = false;
      await tester.pumpWidget(_host(GoEcIntro(ready: ready.future, onFinished: () => finished = true, child: const GoEcIntroPlaceholder())));
      await _pumpFor(tester, 1000);
      ready.complete();
      final ms = 1000 + await _pumpUntil(tester, () => finished);
      expect(finished, isTrue);
      expect(ms, inInclusiveRange(3800, 3950));
    });

    testWidgets('not ready at the bolt: waits there, then flies in', (tester) async {
      final ready = Completer<void>();
      var finished = false;
      await tester.pumpWidget(_host(GoEcIntro(ready: ready.future, onFinished: () => finished = true, child: const GoEcIntroPlaceholder())));

      // Long past the normal 3.8 s end, the bolt is still glowing and nothing has failed.
      await _pumpFor(tester, 6000);
      expect(finished, isFalse);
      expect(find.byType(CustomPaint), findsOneWidget, reason: 'intro should still be up');

      ready.complete();
      final after = await _pumpUntil(tester, () => finished);
      expect(finished, isTrue);
      // Up to half a glow (0.6 s) to come to rest, then the 0.85 s dive.
      expect(after, inInclusiveRange(850, 1550));
      expect(find.byType(CustomPaint), findsNothing, reason: 'intro layer should be gone');
    });

    testWidgets('never ready: goes in after maxWait', (tester) async {
      var finished = false;
      await tester.pumpWidget(_host(GoEcIntro(
        ready: Completer<void>().future,
        maxWait: const Duration(seconds: 5),
        onFinished: () => finished = true,
        child: const GoEcIntroPlaceholder(),
      )));
      await _pumpFor(tester, 4950);
      expect(finished, isFalse);
      final ms = 4950 + await _pumpUntil(tester, () => finished);
      expect(finished, isTrue);
      expect(ms, inInclusiveRange(5000 + 850, 5000 + 1550));
    });

    testWidgets('the default limit is 10 s', (tester) async {
      var finished = false;
      await tester.pumpWidget(_host(GoEcIntro(ready: Completer<void>().future, onFinished: () => finished = true, child: const GoEcIntroPlaceholder())));
      await _pumpFor(tester, 9950);
      expect(finished, isFalse, reason: 'should still be waiting on the bolt');
      final ms = 9950 + await _pumpUntil(tester, () => finished);
      expect(finished, isTrue);
      expect(ms, inInclusiveRange(10000 + 850, 10000 + 1550));
    });

    testWidgets('an error from ready counts as ready', (tester) async {
      final ready = Completer<void>();
      var finished = false;
      await tester.pumpWidget(_host(GoEcIntro(ready: ready.future, onFinished: () => finished = true, child: const GoEcIntroPlaceholder())));
      await _pumpFor(tester, 4000);
      ready.completeError(StateError('offline'));
      final after = await _pumpUntil(tester, () => finished);
      expect(finished, isTrue);
      expect(after, lessThanOrEqualTo(1550));
    });

    testWidgets('reduced motion: the still logo stays up until ready', (tester) async {
      final ready = Completer<void>();
      var finished = false;
      await tester.pumpWidget(_host(
        GoEcIntro(ready: ready.future, onFinished: () => finished = true, child: const GoEcIntroPlaceholder()),
        reduceMotion: true,
      ));
      await _pumpFor(tester, 3000); // well past the 900 ms hold
      expect(finished, isFalse);
      ready.complete();
      final after = await _pumpUntil(tester, () => finished);
      expect(finished, isTrue);
      expect(after, lessThanOrEqualTo(350)); // the 250 ms fade
    });

    testWidgets('reduced motion: maxWait still applies', (tester) async {
      var finished = false;
      await tester.pumpWidget(_host(
        GoEcIntro(
          ready: Completer<void>().future,
          maxWait: const Duration(seconds: 2),
          onFinished: () => finished = true,
          child: const GoEcIntroPlaceholder(),
        ),
        reduceMotion: true,
      ));
      final ms = await _pumpUntil(tester, () => finished);
      expect(finished, isTrue);
      expect(ms, inInclusiveRange(2000, 2350));
    });

    testWidgets('disposed while waiting: no errors', (tester) async {
      final ready = Completer<void>();
      await tester.pumpWidget(_host(GoEcIntro(ready: ready.future, child: const GoEcIntroPlaceholder())));
      await _pumpFor(tester, 4000);
      await tester.pumpWidget(_host(const SizedBox()));
      ready.complete();
      await _pumpFor(tester, 12000);
      expect(tester.takeException(), isNull);
    });
  });
}
