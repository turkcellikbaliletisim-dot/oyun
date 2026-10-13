# Game audio delivery

Twelve sound effects were generated through Runway from the requested original sound descriptions, fitted to their target durations, given short click-free fades, and normalized after Vorbis encoding. Files are OGG/Vorbis, 44.1 kHz, stereo. Four-times oversampled peak checks pass below -1 dBFS; active RMS spread is about 0.21 dB. Listening and in-game mix acceptance remain pending. These are AI-generated sound effects, not recordings of acoustic instruments.

`music_menu.ogg` and `music_battle.ogg` are still the previous original procedural 96-second placeholders. Runway music generation was blocked by the connected workspace's Free plan; no new music generation task was created. A paid Runway plan is required to continue the requested music production.

`spec.json` stores all 14 prompts and delivery rules. `manifest.json` distinguishes source/method for each file and records generation task IDs and decoded measurements. Original MP3 sources, rejected quiet variants, prior effect backups and quality reports remain under `native-builds/` and are excluded from Git/export. No signed download URLs are saved in the manifest.

Validation: `python3 scripts/check-audio.py` from the repository root. Numerical loop-jump checks do not certify musical continuity; both new music loops will require listening before acceptance.
