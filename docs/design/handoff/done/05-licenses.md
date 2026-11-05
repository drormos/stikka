# 05 · Open-source licenses row

Spec: ui-spec.md › Settings › About ("Open-source licenses"). Re-read it first.

1. Settings › About: a new 56px row "Open-source licenses" with ›, under "Privacy policy", no muted line.
2. It opens Flutter's showLicensePage: applicationName "Metra", applicationVersion as on the About version line, no applicationIcon, no legalese.
3. Make it look like part of Metra through the theme only (no custom page): Settings' background, text colors and fonts in both Stage Black and Daylight, a top bar with the same ‹ back chevron, title "Open-source licenses". The per-package license pages follow the same theme.
4. Check that every bundled library (incl. flutter_soloud / SoLoud and anything native you added for the tuner) appears; register any license that Flutter doesn't collect automatically (LicenseRegistry).
5. No phone needed: widget tests + emulator screenshots (both themes, 115% text) into docs/design/screens/licenses-*.png.

Ship it with the next release; no release now.
