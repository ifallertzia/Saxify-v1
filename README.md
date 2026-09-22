# Saxify 

Saxify — *Stream beyond limits.* A neon, YouTube-powered music player built with
Flutter. The frontend is a faithful recreation of the Saxify web app
([saxify.vercel.app](https://saxify.vercel.app)); the playback engine streams audio
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

## v2

Music search, stream resolution and the existing player are unchanged. New
pieces sit beside them.

- Playlist codes talk to `https://saxifyappbackend-for-playlist.onrender.com`.
- Universal Downloader is a separate backend (`https://saxify-downloader.onrender.com`,
  overridable in Settings). It is not a replacement for music search.
- YouTube video download stays refused. Private, login and paywalled links are refused.
- Package id is `com.saxify.app`. It will not install over the old `com.sidify.app`.
  Restore playlists with a cloud code after installing the new app.
- Downloads land in `Download/Saxify/` with a `_saxify` filename suffix.
- Three unfinished launches open safe mode and skip notification and recommendation init.

### Backend you must deploy

Playlist host:

- `POST /playlist` with `{title, songs, app}` and `POST /playlist/all` with `{title, playlists, app}`.
- Respond `200` or `201` with `id` or `code`.
- `GET /playlist/:code` for one playlist. `GET /playlist/all/:code` for a full library.
  The app falls back to the single-playlist route if bulk import is not deployed yet.
- Allow header `X-Saxify-Client: flutter`.

Downloader host (name the app **Saxify Downloader**, version **1.1.0**):

- `GET /api/health` with `status`, `app`, `version`, `ffmpeg`, `yt_dlp`.
- `POST /api/fetch-info` with `{url}`.
- `GET /api/download?url=&type=&format_id=` and support HTTP Range.
- Allow header `X-Saxify-Client: flutter`.
- Do not add a YouTube-video download bypass. The app refuses those links itself.

## In-app updates (Phase 2)
On launch and via Settings → "Check for updates", Saxify compares its version to
GitHub Releases (`releases/latest`) and offers an in-app APK download + install
(`REQUEST_INSTALL_PACKAGES`), so users never need the browser again.

To publish an update:
1. Bump `version:` in `pubspec.yaml`.
2. Create a GitHub Release (tag e.g. `v1.2.0`) and attach the CI-built
   `app-release.apk` asset.
3. Apps on older versions show the "Update available" dialog.
