# Saxify 2.1.0

## What’s new

- Home shelves load on launch, with Hindi- and Indian-music-first recommendations, charts, moods and search.
- Explore now includes devotional, workout, regional and Osho music categories; search results are filtered toward music.
- Trending “Show all” and “Play today’s mix” use the same automatically loaded catalog.
- Improved player loading recovery while keeping Saxify’s existing playback engine; artist pages have more resilient song fallbacks and background playback initialization is retained.
- Download controls show progress on songs. Completed tracks can be played offline and appear under Library → Downloads.
- Universal Downloader now accepts eligible public YouTube URLs and offers best-quality, video-only, video + audio, and audio downloads. Private, login-gated and paywalled content remains unsupported.
- Library JSON backup/import is easier to find and can paste from the clipboard. Cloud playlist-code restore remains a separate server-backed feature.
- First launch asks for a display name; Settings no longer exposes an editable email address. Contact/Report opens a prefilled email draft with report examples.
- Small-screen spacing, Settings cards and accent contrast have been improved.

## Notes

- YouTube universal-download support depends on the deployed Render downloader implementing the required `video`, `video_only` and `audio` modes. See the backend contract in `README.md`; the app does not bypass private or login protections.
- This APK is attached automatically only after the complete `main` build succeeds. The in-app updater reads the latest release from `ifallertzia/Saxify-v1`.
