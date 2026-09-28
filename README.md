# Wedding Draw

A lucky-number draw for a wedding reception (or any event with numbered
tickets), built with Flutter. Press **Draw**: one slot-machine reel per digit
spins, slows down and stops one at a time, then the winning number is revealed
with a chime and confetti. Every winner goes into a list that survives
restarts, and no number is drawn twice.

It is designed to be projected: big numbers that scale to any screen, a
rose-and-champagne theme, and keyboard shortcuts for presenter clickers.

## Features

- **A proper reveal.** Reels spin fast, brake, and stop left to right (at 3 s,
  4.5 s and 6 s for three digits). The winner is announced and saved only when
  the last reel stops. While the reels spin, the Draw button is disabled, so a
  double click cannot cancel a reveal.
- **A fair draw.** Each number is picked uniformly from the numbers that have
  not won yet. When every number has been drawn, Draw is disabled and a
  message explains what to do next. Repeat winners can be allowed in settings.
- **Configurable.** Event title (for example "William & Anna"), ticket range
  (from 0 up to 99999), and whether repeat winners are allowed. The number of
  reels follows the largest ticket number, and numbers are zero-padded, so
  ticket 7 of 200 shows as `007`.
- **Winners list.** Winners are numbered in draw order (#1, #2, …). You can
  remove a single winner (with Undo), take back the last draw, or clear the
  whole list (after a confirmation). The list is a side panel in landscape
  and sits below the reels in portrait.
- **Saved automatically.** Settings, winners and the mute switch are stored
  on the device, so restarting the app halfway through the evening keeps the
  list and still avoids repeats.
- **Sound.** A drum roll while the reels spin, a clack as each reel stops and
  a chime for the winner. The speaker button mutes everything.

## Running a draw

1. Open **settings** (gear icon) and set the event title and the ticket
   range. The default range is 1 to 200.
2. Press **Draw** (or Space). Wait for the reels to stop: the winning number
   appears, is added to the winners list and the confetti starts.
3. Press **Reset** (or Esc) to clear the stage for the next draw, or press
   **Draw again** to go straight to the next one.

Made a mistake? Use the undo arrow in the winners list to take back the last
draw, or the × next to any winner to remove it. Their numbers go back into the
draw. Use the sweep icon to clear the whole list.

**Changing the range keeps the winners.** Numbers that have already won are
still skipped if they are inside the new range; winners outside it stay in
the list, marked "Outside the current range". To start completely fresh,
clear the winners list.

## Keyboard shortcuts

| Keys | Action |
| --- | --- |
| Space, Enter, →, Page Down | Draw (when nothing is on screen) |
| Esc, ←, Page Up | Reset after a winner has been revealed |

Most presenter clickers send → / Page Down for "next" and ← / Page Up for
"previous", so "next" draws and "previous" clears the stage. The draw keys do
nothing while the reels spin or while a winner is on screen, so a stray click
can never skip past a winner before it has been announced: clear the stage
first, then draw.

## Running the app

You need Flutter 3.38 or newer. The app was built and tested with Flutter
3.44.6 (Dart 3.12).

```sh
flutter pub get

flutter run -d chrome     # web
flutter run -d windows    # Windows desktop (on Windows)
flutter run -d macos      # macOS desktop (on a Mac)
flutter run               # a connected Android or iOS device
```

Release builds:

```sh
flutter build web --release   # static site in build/web; host it anywhere
flutter build windows
flutter build macos
flutter build apk --release   # Android
flutter build ipa             # iOS (needs Xcode and signing)
```

This repository has no Linux runner; add one with
`flutter create --platforms=linux .` if you need it.

Tips for the venue:

- A laptop running the web or desktop build in full screen (F11 in most
  browsers) works well with a projector.
- Browsers only allow sound after the first click or key press on the page.
  The first Draw counts, so sounds work from the first draw on.
- Winners are saved in the browser or on the device you use. Run the draw
  from the same browser profile or device all evening.
- No internet is needed: the font and sounds are bundled. One exception: on
  the web, characters the bundled Roboto font lacks (for example Chinese
  names in the title) are downloaded from Google Fonts. Desktop and mobile
  builds use the system fonts for those instead.

## Development

```sh
flutter analyze
flutter test
```

Code layout:

| Path | Contents |
| --- | --- |
| `lib/main.dart` | App entry point and theme |
| `lib/src/draw/` | `DrawPool` (pure draw logic, injectable `Random`) and `DrawController` (app state) |
| `lib/src/settings/` | `DrawSettings` and `DrawStorage` (shared_preferences) |
| `lib/src/audio/` | `SoundEffects` interface, audioplayers implementation and a silent one for tests |
| `lib/src/ui/` | Draw screen, reels, winners list, settings dialog, confetti |
| `tool/generate_sounds.py` | Synthesizes `assets/sounds/*.wav` (Python standard library only) |

The reveal timings are constants in `SpinTiming` (`lib/src/ui/reel_spin.dart`).
To change the sounds, edit `tool/generate_sounds.py` and run
`python3 tool/generate_sounds.py`.
