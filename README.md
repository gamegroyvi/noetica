# noetica

Second brain · growth tracker · memoir.

A Flutter app for the people who want a single tool for thinking,
remembering, and growing.

## Vision

Noetica is built around three layers tied to a single time axis:

- **Now** — tasks and reminders (what I'm doing).
- **Self** — a user-defined growth pentagon (who I'm becoming).
- **Past** — a memoir-style timeline with explicit time gaps between
  entries (who I was).

Every note or task is anchored to a timestamp and one or more growth
axes. Completing a task awards XP that decays over a 30-day window, so
the pentagon reflects "you right now", not the sum of your life.

## Stack

- Flutter 3.24, Dart 3.5
- Riverpod for state management
- sqflite (mobile) / sqflite_common_ffi (desktop) for local storage
- google_fonts (Inter) for typography
- Strict black-and-white theme, no gradients

## Run

```sh
flutter pub get
flutter run            # picks the first available device
flutter test           # widget tests
flutter analyze        # static analysis
```
