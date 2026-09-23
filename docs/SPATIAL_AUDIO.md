# IfallMusic — real-time 8D spatial audio processor

This document is the design + implementation reference for the **8D spatial
audio** template that lives in *Equalizer & 8D audio*.

## 1. What the effect actually is

Three stages, always in this order:

| Stage | What it does | Where |
| --- | --- | --- |
| 1. Low-frequency oscillator panning | `pan(t) = sin(2π · f · t)`, `f` = 0.03–0.5 Hz, drives the stereo image left ↔ right | `SpatialAudioProcessor.render()` |
| 2. Depth / width | Mid/side matrix: `side ×= (1 + width)`, `mid ×= (1 − 0.15 · depth)` | same |
| 3. Early-reflection reverb | 3 prime combs (2113 / 2713 / 3371 samples) + one 4093-sample all-pass diffuser, feedback 0.72 | same |

Gains follow the **equal-power law** so the perceived loudness never pumps while
the sound orbits:

```text
θ     = (pan + 1) · π/4          // 0 … π/2
left  = cos(θ)
right = sin(θ)
```

A one-pole smoother (α = 0.02) removes zipper noise at block edges.

## 2. Code structure (Flutter side)

```text
lib/core/services/spatial_audio_service.dart
├── SpatialPreset            immutable template (Hz, depth, reverb, width)
├── SpatialPresets           Off · 8D Orbit · Swift · Cinematic · Dreamy · Focus · Club
└── SpatialAudioService      ChangeNotifier
    ├── pan / gains          live LFO state (equal-power)
    ├── orbitStream()        UI visualisation stream
    ├── applyPreset()        switch template (persists + pushes to native)
    ├── setDepth() / setRotationHz() / setReverb() / setEnabled()
    └── _push()              → NativeBridge.spatialApply(...)
```

* UI: `lib/ui/player/sound_panel.dart` → `SpatialControls` (templates, sliders,
  live orbit meter). It is embedded in the player's **Sound** sheet
  (`full_player_page.dart`) and in the equalizer page.
* Persistence: `SettingsService` keys `saxify.spatial_preset|depth|speed|reverb`.

## 3. Code structure (native side)

```text
android/app/src/main/kotlin/com/saxify/app/
├── SpatialAudioProcessor.kt   sample-accurate DSP (render/reset/latencySeconds)
└── SaxifyBridge.kt
    ├── spatialApply(rotationHz, depth, reverb, width)
    ├── spatialDisable()
    └── releaseSpatial()       Virtualizer + EnvironmentalReverb on the session
```

`SaxifyBridge` gives the stock player an audible spatial stage today:
`android.media.audiofx.Virtualizer` (the "around your head" width) and
`android.media.audiofx.EnvironmentalReverb` (the room). Both attach to the live
audio session reported by the equalizer; when that is unavailable they fall back
to the global output mix (session `0`). Requires
`android.permission.MODIFY_AUDIO_SETTINGS` (already declared).

## 4. Native libraries / plugins that fit this job

| Need | Recommended | Notes |
| --- | --- | --- |
| Insert the DSP into the player pipeline | **AndroidX Media3 `AudioProcessor`** (ExoPlayer) | `DefaultAudioSink.Builder().setAudioProcessors(...)`; this is the cleanest hook for `SpatialAudioProcessor.render()` — just wrap the PCM block |
| Lowest-latency output, own engine | **Oboe** (C++) / **AAudio** (NDK) | `AudioStreamBuilder().setDataCallback(...)`; feed the same `render()` |
| Pro DSP / true 3D | **Superpowered SDK**, **Sonic** (rate/pitch), **Rubber Band** | Superpowered ships an ambisonic/3D panner |
| System-level spatialisation | `Virtualizer`, `EnvironmentalReverb`, `PresetReverb`, `DynamicsProcessing` | zero-dependency, works with any player (used here) |
| Flutter playback | `just_audio` (`AudioPipeline.androidAudioEffects`), `audio_service` | keep the existing player; effects ride on top |
| Flutter, own 3D mixer | `flutter_soloud` (SoLoud) | real 3D positional audio + panning if the app ever owns the mixer |

## 5. Wiring the sample-accurate path (Media3)

```kotlin
class SpatialAudioProcessorFactory(
    private val processor: SpatialAudioProcessor,
) : AudioProcessor.Factory {
    override fun createAudioProcessor(): AudioProcessor =
        object : BaseAudioProcessor() {
            override fun queueInput(input: ByteBuffer): Boolean {
                val buffer = input as ByteBuffer
                val shorts = buffer.order(ByteOrder.nativeOrder()).asShortBuffer()
                val pcm = ShortArray(shorts.remaining())
                shorts.get(pcm)
                processor.render(pcm, pcm.size / 2)   // stereo frames
                val out = replaceOutputBuffer(pcm.size * 2)
                out.order(ByteOrder.nativeOrder()).asShortBuffer().put(pcm)
                out.flip()
                return true
            }
        }
}
```

Then: `DefaultAudioSink.Builder().setAudioProcessors(arrayOf(factory)).build()`.

## 6. Tuning guide

| Musical intent | `rotationHz` | `depth` | `reverb` | Template |
| --- | --- | --- | --- | --- |
| Subtle space, wide | 0.03 | 0.45 | 0.25 | 8D Focus |
| Classic 8D | 0.12 | 0.90 | 0.30 | 8D Orbit |
| Club / EDM | 0.34 | 1.00 | 0.22 | 8D Club |
| Cinematic | 0.07 | 0.75 | 0.70 | 8D Cinematic |
| Ambient / lofi | 0.05 | 0.60 | 0.85 | 8D Dreamy |

Faster than ~0.4 Hz starts to sound like tremolo rather than movement; above
~0.85 reverb the tail smears lyrics.
