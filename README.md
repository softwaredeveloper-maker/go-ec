# goec_intro

The Go EC launch animation as one Flutter widget. The logo builds itself, the bolt sparks, and the camera flies through the bolt into the app's first screen. Runs 3.8 s.

No images, fonts or packages: the logo is drawn from shapes in code. Flutter 3.10 or newer.

## Add it to the app

**1. Copy the folder** into the repo, for example `packages/goec_intro`, and add it to `pubspec.yaml`:

```yaml
dependencies:
  goec_intro:
    path: packages/goec_intro
```

**2. Wrap the first screen.** `child` is the screen the camera flies into (in Go EC that is the maps screen):

```dart
import 'package:goec_intro/goec_intro.dart';

MaterialApp(
  home: GoEcIntro(
    child: const MapsScreen(),
    onFinished: () {
      // Intro is gone and the maps screen is live.
    },
  ),
);
```

That is the whole integration. What happens to `child`:

- It is built straight away, under the intro, so the map can start loading while the logo plays.
- It is not drawn until the bolt opens (about 3.1 s, or later if the intro [waits for the map](#waiting-for-the-map)), then appears inside the bolt and fills the screen.
- Touches are blocked until the intro ends. After that the intro removes itself and `child` keeps its state, so there is no route change and nothing to pop.

**3. Keep the first screen quiet during the intro.** Anything that pops up over the animation breaks it. Move these into `onFinished` or later:

- location permission prompts and other dialogs
- snackbars, toasts, onboarding sheets

Loading data and map tiles in the background is fine.

**4. Make the native launch screen plain blue `#003DBA`**, the intro's first colour, so launch goes native splash, then intro, with no flash:

- Android: `android/app/src/main/res/drawable/launch_background.xml` (and `drawable-v21`). On Android 12+ also set `android:windowSplashScreenBackground` to `#003DBA` in `values-v31/styles.xml`. Android 12+ always shows the app icon on its splash; that is the system's, not ours.
- iOS: `ios/Runner/Base.lproj/LaunchScreen.storyboard`, background `#003DBA`, no logo.

The Android side is already done in `example/android/app/src/main/res` (`drawable*/launch_background.xml` and the three `styles.xml`). Copy from there.

## Waiting for the map

On a slow first launch the map may not be ready when the bolt opens. Pass `ready` and the intro waits for it: the camera stops on the bolt just before it flies in, and the bolt glows softly, about once every 1.2 s, until `ready` completes. Then the camera flies into the map.

```dart
// Create it once (here, in main), not in a build method.
final mapReady = Completer<void>();

MaterialApp(
  home: GoEcIntro(
    ready: mapReady.future,
    child: MapsScreen(
      // Call this when the map is created AND the charger markers are on it.
      onChargersShown: () {
        if (!mapReady.isCompleted) mapReady.complete();
      },
    ),
    onFinished: () {
      // Pop-ups from here, as before.
    },
  ),
);
```

- **What counts as ready:** the map is created and the charger markers are on it. The map tiles alone are not enough, because tiles seen before load from the phone's cache even without internet.
- **What not to wait for:** the ad and the location permission prompt. They come after `onFinished`, so waiting on them would hold until `maxWait`.
- **No network at launch:** complete `ready` straight away, so nobody watches the bolt for nothing.
- **`maxWait`** (default 10 s, counted from the intro's first frame) is the longest it waits. After that it flies into the map anyway, and the map shows its own loading or offline state. An error from `ready` counts as ready.
- **Ready in time:** nothing changes. The animation plays straight through in 3.8 s, with no pause.
- **Still logo** (reduce motion, slow phone): it stays up until `ready` too, within `maxWait`, without the glow.

Try it in the demo app: long-press to replay with a map that takes 6 s, double-tap for a map that never loads (no internet), which goes in at the 10 s limit. The result card shows how long the intro took.

## Fallback

The animation never plays badly. Two cases get a still version instead:

| When | What the user sees |
|---|---|
| Reduce motion is on in the phone's settings | The finished logo for 0.9 s (longer if it is [waiting for the map](#waiting-for-the-map)), then a 0.25 s fade into the first screen |
| The phone can't keep up | Checked on the first 12 frames (about 0.2 s in). If most of them miss the screen's refresh, the logo fades to its finished state, holds 0.9 s (or until the map is ready) and fades into the first screen |

Change the hold with `staticHold: Duration(milliseconds: 600)`.

The phone check only runs in profile and release builds. Debug builds are always slow, so they always play the animation (choppily on weak phones). Judge smoothness with `flutter run --profile` or `--release`, never debug.

`skipOnSlowFrames: false` turns the check off. Use it only for screen recordings, where capturing slows every frame.

## Why it's light

- One animation controller repaints one canvas. Nothing rebuilds during the animation, nothing is laid out, nothing is decoded.
- Each frame fills about 15 shapes, plus two soft gradients during the spark and one while waiting for the map.
- The first screen isn't drawn while the logo covers it.
- No assets: about 35 KB of Dart source, adding nothing to the download beyond that.

## Options

| Option | Default | |
|---|---|---|
| `child` | required | The first screen of the app |
| `onFinished` | none | Called once when the intro is gone |
| `onFallback` | none | Called with `GoEcFallback.slowPhone` or `.reducedMotion` if the still logo was shown. Handy for analytics |
| `ready` | none | A future that completes when the first screen is ready. Until then the intro waits on the glowing bolt. See [Waiting for the map](#waiting-for-the-map) |
| `maxWait` | 10 s | The longest it waits for `ready`, from the intro's first frame |
| `staticHold` | 900 ms | How long the still logo stays up in the fallback |
| `skipOnSlowFrames` | `true` | The slow-phone check |
| `rollLetters` | `true` | g, o, c roll in like wheels; `false` slides them without turning |

## Changing the animation

- Timings: `_Timeline` at the top of `lib/src/goec_intro.dart`, every step in ms.
- Shapes: `lib/src/geometry.dart`, in pixels of the master logo artwork.

## Try it on its own

- Android app: [latest APK](https://github.com/Dhruvnathmenon/go-ec/releases/tag/demo). This is the real test of smoothness.
- Browser: [dhruvnathmenon.github.io/go-ec](https://dhruvnathmenon.github.io/go-ec/). Quick look only; a phone browser runs Flutter slower than the app does.

Both rebuild on every push to `main` (`.github/workflows/demo.yml`). After each run the demo says which version played and the frame rate. Tap to replay.

Locally:

```bash
cd example
flutter run --release
```

The example uses a still of the maps screen as `child`. Tests: `flutter test` in this folder.
