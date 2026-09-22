# Saxify 

Sidify — *Stream beyond limits.* A neon, YouTube-powered music player built with
Flutter. The frontend is a faithful recreation of the Sidify web app
([sidify.vercel.app](https://sidify.vercel.app)); the playback engine streams audio
straight from YouTube with resilient multi-client stream resolution.

## Features
- **Home** — hero greeting, Made for you, Mood & genres, Trending now, New releases,
  Top artists and Recommended for you (personalised from your listening).
- **Search** — the same YouTube search backend, styled result rows.
- **Library** — Liked Songs, Playlists (create/rename/delete), Songs, Artists, History.
- **Player** — persistent mini-player, full player with seek / shuffle / repeat /
  speed / sleep timer / queue, gapless pre-load and auto-next to related tracks.
- **Albums & Artists** — `ytq-` encoded album pages and channel pages, like the site.
- **Settings** — appearance with 6 rotating neon accents (auto every ~2.5 min or pinned),
  playback & audio engine, and "Instructions to play in background".
- **Persistence** — likes, playlists, history and settings saved locally.

## Engine
`lib/core/services/playback_service.dart` keeps the original HEAD-probe +
androidSdkless → ios → androidVr fallback that works around the YouTube 2026
anti-bot 403s (youtube_explode_dart #332).

## Build
```
flutter pub get
flutter run
```
CI builds a release APK on every push / PR (see `.github/workflows/build_apk.yml`).

## In-app updates (Phase 2)
On launch and via Settings → "Check for updates", Sidify compares its version to
GitHub Releases (`releases/latest`) and offers an in-app APK download + install
(`REQUEST_INSTALL_PACKAGES`), so users never need the browser again.

To publish an update:
1. Bump `version:` in `pubspec.yaml`.
2. Create a GitHub Release (tag e.g. `v1.2.0`) and attach the CI-built
   `app-release.apk` asset.
3. Apps on older versions show the "Update available" dialog.
