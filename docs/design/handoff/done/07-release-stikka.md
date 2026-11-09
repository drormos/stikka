# 07 · Release 1.10.0: Stikka

Depends on 06 (the rename) being done. Use the release skill. Don't upload, tag or push unless Dror asks.

1. **Version:** 1.10.0, next build number.
2. **What's new** (in the app, max 4 lines) and **Play release notes** (≤500 characters, same lines):
   - Metra is now called Stikka. Same app, and all your songs are here.
   - Settings › About now lists the open-source licenses.
   - Also update CHANGELOG `[1.10.0]` (mention the rename and that old exports still import), assets/whats_new.md and store/listing.md.
3. **Privacy:** PRIVACY.md must be online under the URL the app opens before Dror sends the build for review. If the repo was renamed in 06, check that the new URL serves the policy and that the old one redirects.
4. **Upgrade check:** on the emulator, from 1.9.0 (109) to this build. 06 already did it; repeat it on the signed release build.
5. **The guard:** the release script runs the no-"Metra" test and refuses to build if it fails.
6. Build the signed AAB. Report its path, the version, the exact release notes to paste, and the Play Console steps from 06 §8 that must happen with this upload (store listing name, feature graphic, privacy URL).
