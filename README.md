# Saxify

*Stream beyond limits.* Saxify 2.1.0 is a Flutter music player with Hindi-first discovery, Android background playback, a local library and an on-device downloader. Canonical releases and updates: [ifallertzia/Saxify-v1](https://github.com/ifallertzia/Saxify-v1/releases).

## Listen and discover

- Home shelves load automatically; search and moods favor songs, Indian music and long-form music (including mixes and Osho meditation). Artist rails resolve real photos where available.
- The existing `PlaybackService` resolves YouTube streams for `just_audio`, manages a queue, auto-next, speed, quality and notification controls. Stream interruptions trigger URL re-resolution, a seek to the last position and a retry. Android keeps its media notification and a playback wake lock while playing.
- Android player Sound opens a translucent volume/equalizer panel attached to the active audio session. Equalizer hardware support varies by device; volume works even when an equalizer is unavailable.
- Library → Your Downloads plays previously saved songs from app-private files. Offline playback works without internet; **a new YouTube download still requires internet to retrieve the source**, even though no Saxify download server is involved.
- Library JSON backup/import is local. Playlist code sync uses a separate pre-existing cloud service and is not involved in downloads.

## Download media on the phone (Android)

The song Download button and Add link/Bulk use the same bundled `youtubedl-android` (yt-dlp + FFmpeg) native bridge. Public YouTube and other yt-dlp-supported URLs are resolved on the device. Nothing calls a Render/downloader backend. Private, paid, login-gated or unsupported sources are not bypassed.

1. On a song, tap Download; watch its percentage on the song row, then open Library → Your Downloads or Settings → Music downloads to play/delete the offline copy.
2. For a public URL, open the Downloader, paste/fetch a link, choose best/explicit format and video + audio, video only, or MP3 audio. Bulk accepts multiple URLs and runs through the same local pipeline.
3. Completed files are kept app-private for reliable offline playback. A best-effort copy is also published under `Download/Saxify` through Android MediaStore (legacy Downloads on Android 9 and earlier). Android 9 and earlier may need storage permission for the public copy. Cancelling removes partial private files. If MediaStore is unavailable, the private offline copy is still available.

Files keep their real extensions/containers (e.g., M4A, WebM, MKV); yt-dlp + bundled FFmpeg convert the MP3 option. Downloads can be played only after they have finished; this app does not promise offline *fetching*. On non-Android platforms, the existing playable-stream audio fallback is used for song downloads; the yt-dlp link downloader is Android-only.

**Licensing:** Inter is bundled under the SIL Open Font License; see `assets/fonts/OFL.txt`. The bundled `youtubedl-android`/yt-dlp integration includes GPL-3.0-licensed components. Anyone distributing an APK should review the applicable GPL source/attribution and distribution obligations alongside their other dependencies.

## Build and releases

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

`pubspec.yaml` declares 2.1.0+4. The updater reads the latest release from [`ifallertzia/Saxify-v1`](https://github.com/ifallertzia/Saxify-v1/releases) and looks for `app-release.apk`. `RELEASE_NOTES.md` is also bundled verbatim as the in-app What's new list. The existing GitHub Actions workflow publishes a versioned APK only after a successful default-branch build; feature-branch builds never create a release.
