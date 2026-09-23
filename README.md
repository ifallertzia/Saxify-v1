# Saxify

Saxify — *Stream beyond limits.* A neon, YouTube-powered music player built with Flutter. Version **2.1.0** is being prepared from `ifallertzia/Saxify-v1`.

## Features

- **Home & Explore** — automatically loaded India-first shelves and stations, including Hindi/Bollywood, devotional, workout, regional, and Osho categories.
- **Search** — song-focused results, biased toward Hindi and Indian music; search and catalog selection continue to use the existing YouTube-based music service.
- **Player** — Saxify’s existing playback engine, with a persistent mini-player, full player controls, queue, gapless pre-load, auto-next, and background media-session initialization.
- **Artists & albums** — YouTube metadata with Hindi-first music-search fallbacks when channel or release data is unavailable.
- **Library** — Liked Songs, Playlists, Songs, Indian Artists, Downloads, and History.
- **Song downloads** — live progress, private offline copies, and playback from Library → Downloads.
- **Universal Downloader** — separate from music playback; bulk public URLs, best-quality defaults, video-only, video + audio, and audio modes.
- **Profile & Settings** — a first-launch display name, theme accents, playback settings, diagnostics, contact/report drafts, and backup tools.

## Playback engine

`lib/core/services/playback_service.dart` retains Saxify’s existing HEAD-probe and `androidSdkless` → `ios` → `androidVr` stream fallback. New catalog and download controls do not replace that player.

## Local library JSON vs. playlist codes

These are different backup paths:

- **Library JSON** is exported/imported locally from Library → backup or Settings → Backup library. It covers likes, songs, playlists, history, and followed artists. It is not uploaded to Render. Clipboard paste and merge/replace are supported.
- **Playlist codes** are server-backed and require the playlist Render service. Generating a single code uses `POST /playlist`; generating all playlists uses `POST /playlist/all`. Restoring one playlist uses `GET /playlist/:code`; restoring all playlists uses `GET /playlist/all/:code`. The app tries the bulk route first and falls back to the single-playlist route.

If the playlist service does not implement one of those routes, local JSON backup/import still works; the missing server route must be deployed for that cloud-code operation.

## Render downloader contract

The app’s default universal-downloader host is `https://saxify-downloader.onrender.com` (overridable in Settings). The app now sends eligible public YouTube URLs to this backend. It does not provide cookies or bypass private, login-gated, or paywalled content.

The deployed service must implement and verify all of the following before YouTube downloads can be considered functional:

- `GET /api/health` returning `status`, `app`, `version`, `ffmpeg`, and `yt_dlp`.
- `POST /api/fetch-info` accepting `{ "url": "..." }` and returning a title, thumbnail, duration, and usable format metadata. It must allow supported public YouTube URLs through its `yt-dlp` resolver without credentials/cookies.
- `GET /api/download?url=...&type=...&format_id=...` with HTTP Range support. `type` values sent by the app are `video`, `video_only`, and `audio`; omitted `format_id` means best available quality. The server should merge best video + audio for `video`, return a video-only stream for `video_only`, and provide audio/MP3 for `audio`.
- `X-Saxify-Client: flutter` and the app User-Agent must be accepted.
- Private/login-required media should return a clear unsupported/authorization error; do not use session cookies or defeat those restrictions.

**Backend status is unverified from this workspace:** Render host TLS handshakes failed here, so this repository cannot confirm deployed health, routes, or formats. The exact server work to check is `/api/fetch-info` public-YouTube handling plus `/api/download` support for the three `type` values above, including best-quality selection, format IDs, range streaming, and error handling. Do not treat the client change as proof those Render routes exist.

## In-app updater and releases

The updater checks the latest release from `ifallertzia/Saxify-v1` and looks for an APK asset named `app-release.apk`. The Actions workflow builds on this feature branch and on pull requests, but **never publishes a release from those runs**. A versioned GitHub Release (`v<version>`) with the APK is created only when the complete build job succeeds on the default `main` branch. Release notes come from `RELEASE_NOTES.md`.

To prepare a later release, bump `version:` in `pubspec.yaml`, keep `SaxifyBranding.versionLabel` and `RELEASE_NOTES.md` aligned, then merge after review. The post-merge `main` build publishes the matching APK for the in-app updater.

## Build

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

CI also builds a release app bundle. Flutter analysis, all unit/widget tests, APK, and AAB builds are blocking steps; any failure prevents release publication.
