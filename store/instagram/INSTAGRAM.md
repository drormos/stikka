# Stikka on Instagram

Images, all checked against the 2026 specs:

| Folder | Size | Use |
|---|---|---|
| `posts/` | 1080×1350 (4:5) | Feed carousels. 4:5 is the tallest size Business Suite schedules (3:4 works only in the app). The grid shows slide 1 cropped to 3:4 (45px off top and bottom); nothing important sits there. |
| `stories/` | 1080×1920 (9:16) | Stories. Content stays inside the safe zone (about 250px clear at top and bottom). |
| `profile/profile-picture.png` | 1080×1080 | Instagram profile picture (circle crop) |
| `profile/highlight-*.png` | 1080×1080 | Highlight covers: square, so the circle takes the whole image with no zooming |
| `facebook/page-picture.png` | 1080×1080 | Facebook Page profile picture |
| `facebook/page-cover.png` | 1640×624 | Facebook Page cover (2× of 820×312). Content stays in the centre, so the mobile crop keeps it all. |
 Regenerate with `python3 store/instagram/gen.py` (needs Pillow; it reads the store screenshots, design screens and the app fonts).

---

## 1. Profile

**Profile picture:** `profile/profile-picture.png` (the app icon with room for the circle crop).

**Name** (searchable, so include what it is):
`Stikka · Metronome for drummers`

**Category:** App page (or Software). Hide the category in the profile display if it looks odd.

**Bio** (139 / 150):
```
Metronome for practice, rehearsal and the stage.
Song parts · setlists · stage mode · tuner
Free, no ads. Made by a drummer.
Android test ↓
```

**Links** (Instagram allows up to 5; order matters, the first one shows):
1. `Join the test (step 1)` → the Google Group page: https://groups.google.com/g/metra-testers (check this is the exact URL)
2. `Get the app (step 2)` → the Play testing opt-in link

Play only lets group members in, so step 1 must come first. Put the Play testing link in the Google Group's description too, so one link is enough if someone only taps the first.

**Highlights** (covers in `profile/`, add in this order):
| Highlight | Cover | What goes in it |
|---|---|---|
| Join | highlight-1-join.png | The CTA slide + a story with the link sticker to the group, then the Play link |
| Parts | highlight-2-parts.png | Post 02 and 03 slides (song parts, heads-up) |
| Stage | highlight-3-stage.png | Post 04 slides |
| Sets | highlight-4-sets.png | Post 05 slides |
| Practice | highlight-5-practice.png | Posts 06 and 07 slides |
| Tuner | highlight-6-tuner.png | Post 08 slides |

Story images (9:16, 1080×1920) to seed each highlight are in `stories/`: story-1-join … story-6-tuner. Put the link sticker on story-1-join in the empty band under "Tap the link to start". After that, share each post to your story (or upload the slide as a story), then add it to the highlight. Covers are square (1080×1080), so they fit the circle as they are.

---

## 2. Posts

Instagram allows at most 5 hashtags per post now, so every caption has exactly 5. Each carousel ends with the same "Free on Android" slide.

### 01 · Meet Stikka  (`posts/01-meet-stikka/`, 4 slides)
1. A metronome built by a drummer. (main screen, heads-up)
2. Whole songs, not just a click. (parts page)
3. Made for the stage. (stage mode)
4. Free on Android / join steps

Caption:
```
I'm a drummer, and I wanted a metronome that just works, in the practice room and on stage. So I built one.

Stikka plays whole songs: intro, verse, a one-bar 2/4 break, the chorus that pushes from 128 to 140. One tap and it plays it all, with a heads-up before every change.

It's free. No ads, no account, no tracking.

Android only for now, in closed testing. Want in? Links are in the first comment: join the testers group, then install from Google Play.

#metronome #drummer #drumming #musicapp #androidapp
```

### 02 · Song parts and tempo changes  (`posts/02-song-parts/`, 5 slides)
1. Your song changes tempo. Your click should too.
2. Build a song from parts.
3. Speed up across a part. (Chorus 128 → 140)
4. Odd meters? Covered. (Rhythm panel, 7/8)
5. CTA

Caption:
```
Most songs aren't one tempo from start to finish. Your metronome shouldn't be either.

In Stikka a song is a list of parts. Each part has its own length, tempo, time signature and accents. Need the chorus to push from 128 to 140? Set a gradual change and it ramps smoothly across the part.

Odd bars, 7/8, a 2/4 break: all in one song, all from one tap.

Free on Android.
Links to join the test are in the first comment.

#metronome #drummer #drumpractice #clicktrack #musicapp
```

### 03 · Heads-up before a part change  (`posts/03-heads-up/`, 4 slides)
1. Never miss the break again.
2. A warning, then a countdown. (stage mode, "Break in 2 bars")
3. Lost your place? Tap the map.
4. CTA

Caption:
```
That one-bar break after a long verse. Every drummer knows it.

Stikka warns you before every part change: "Break in 2 bars · 2/4 · 128", then counts down the beats of the last bar. You can also turn on a higher click on the first beat of each new part.

Lost your place? Tap any part on the song map to jump there.

Free on Android.
Links to join the test are in the first comment.

#drummer #drumming #metronome #livemusic #bandlife
```

### 04 · Stage mode  (`posts/04-stage-mode/`, 4 slides)
1. Big screen. Big buttons. No accidents.
2. Next song, one tap.
3. Hold to exit.
4. CTA

Caption:
```
On stage you don't want menus. You want the song name, the tempo, and a big button.

Stage mode shows only that: big Previous, Next and Start, the heads-up for the next part, and a hold to exit, so a stray touch never takes you out.

Step through the set with the buttons, the lock screen, or a Bluetooth page-turner pedal.

Free on Android.
Links to join the test are in the first comment.

#livemusic #gigging #drummer #setlist #metronome
```

### 05 · Setlists and sharing with the band  (`posts/05-setlists-sharing/`, 4 slides)
1. The whole gig in your pocket.
2. Send the set to the band. (Share menu)
3. Or send the songs themselves. (Export)
4. CTA

Caption:
```
Tonight's set, every tempo, every part. In your pocket, and in your band's.

Save songs with their tempo, rhythm and parts, then build setlists. Send the running order with tempos to the band chat in one tap. Or export the whole set, parts and all, and your bandmates import it into their own Stikka.

Free on Android.
Links to join the test are in the first comment.

#setlist #bandlife #drummer #musicapp #gigging
```

### 06 · Practice speed  (`posts/06-practice-speed/`, 4 slides)
1. Learn it at 80%. Play it at 100%.
2. Slow the whole song down.
3. On stage too.
4. CTA

Caption:
```
Learn it slow. Play it at full speed.

Practice speed plays the whole song at 80% (or any speed you choose), with every part and every tempo change in proportion. Turn on Loop song and it gets a little faster each time around, up to 100%.

Free on Android.
Links to join the test are in the first comment.

#drumpractice #practice #drummer #metronome #musician
```

### 07 · Count-in and speed up  (`posts/07-count-in/`, 3 slides)
1. Count yourself in.
2. Speed up as you go.
3. CTA

Caption:
```
Hit Start, get a bar to breathe.

A 1 or 2 bar count-in, shown on screen as it counts. For building speed, Speed up adds a few bpm every few bars, up to the tempo you set. Or let it stop after a number of bars or minutes.

Free on Android.
Links to join the test are in the first comment.

#drumpractice #drummer #practice #metronome #drums
```

### 08 · The tuner  (`posts/08-tuner/`, 3 slides)
1. A tuner for the whole band.
2. Set your A4.
3. CTA

Caption:
```
Your guitarist forgot the tuner again? Hand them your phone.

Stikka now has a chromatic tuner: a big note name, cents off, and a smooth needle. Reference A4 from 430 to 450 Hz. The mic is used only while the tuner is open, and nothing is recorded or sent.

Free on Android.
Links to join the test are in the first comment.

#tuner #guitar #bass #bandlife #musicapp
```

### 09 · Free, no ads, private  (`posts/09-free-private/`, 4 slides)
1. No ads. No account. No tracking.
2. Why free?
3. Dark or Daylight.
4. CTA

Caption:
```
No ads. No account. No tracking. Not "for now". That's the plan.

Stikka has no internet access at all, so your songs stay on your phone. I built it because I wanted a metronome as good as the paid ones, without the ads, and I want other musicians to have it too.

Free on Android.
Links to join the test are in the first comment.

#metronome #musicapp #androidapp #drummer #musician
```

---

## Reels ideas

Short (15–30 s), vertical, real playing. Record the screen with the clean status bar from `store/listing.md` (demo mode), and film the kit with the phone visible.

**R1 · "The break that always catches you"** (heads-up)
- 0–3 s: on screen text "That one 2/4 bar after a long verse…" while you play the verse.
- 3–10 s: close-up of the phone: "Break in 2 bars", the countdown.
- 10–15 s: you nail the break. Text: "Stikka warns you before every change."
- Caption: post 03's, shortened.

**R2 · "Set up tonight's gig in 30 seconds"** (setlists + stage mode)
- Sped-up screen recording: build a song with three parts, add it to a set, open stage mode, tap Start.
- End card: the CTA slide.

**R3 · "80% → 100%"** (practice speed)
- One hard fill, looped. Each pass a little faster; show the % tag growing on screen. Text: "Learn it slow. Play it at full speed."

**R4 · "Guitarist forgot the tuner"** (tuner)
- Your bandmate tunes on your phone, needle centres on "In tune". 10 s, funny is fine.

---

## 3. Schedule (all scheduled in Meta Business Suite, 20:00 Israel time, Instagram + Facebook Page)

| Date | Post | Folder |
|---|---|---|
| Sun Nov 8 | 01 Meet Stikka | posts/01-meet-stikka |
| Tue Nov 10 | 03 Heads-up | posts/03-heads-up |
| Thu Nov 12 | 02 Song parts | posts/02-song-parts |
| Sat Nov 14 | 09 Free and private | posts/09-free-private |
| Mon Nov 16 | 04 Stage mode | posts/04-stage-mode |
| Wed Nov 18 | 05 Setlists and sharing | posts/05-setlists-sharing |
| Thu Nov 19 | 07 Count-in | posts/07-count-in |
| Sat Nov 21 | 06 Practice speed | posts/06-practice-speed |
| Sun Nov 22 | 08 Tuner | posts/08-tuner |

Not scheduled (need filming): reel R1 around Nov 13, reel R2 around Nov 20.

On each post day (phone, 1 minute): share the post to your story, add it to its highlight, reply to comments in the first hour.

The captions are the same on Instagram and Facebook. Right after each post goes up, add this as the first comment on both:
```
Join the test in 2 steps:
1. Join the testers group: https://groups.google.com/g/metra-testers
2. Install from Google Play: <Play testing link>
```
On Facebook the links in the comment are tappable. On Instagram they are plain text, so the bio links stay the tappable way in.

---

## Rename (Metra → Stikka, November 2026)

Everything above now says Stikka, and every image was regenerated with `gen.py` (only the name in the corner and the slide text changed). The Google Group keeps its URL, `metra-testers`: Google can't rename a group, so the join slides still show it. `posts/10-rename/` and `stories/story-0-rename.png` are the rename announcement ("Metra" → "Stikka", on purpose). Reel R2 still shows "Metra" in its corner; it isn't scheduled, so it wasn't rebuilt (run `reels.py r2 <recording>` before posting it).

What to change, in this order:
1. **Instagram:** Edit profile › Name: `Stikka · Metronome for drummers`. Then the username, if @stikka (or the handle you chose) is free. The profile picture is the app icon with no wordmark, so it stays.
2. **Facebook Page:** Settings › Page name: Stikka (Meta reviews name changes, usually within a few days). Upload the new cover, `facebook/page-cover.png`. The page picture is unchanged.
3. **Meta Business Suite:** delete every scheduled post from Nov 10 on (they show "Metra") and schedule the regenerated ones from the same folders, same dates and times. For the Nov 8 "Meet Metra" post: archive it and post `posts/01-meet-stikka/` (with the caption above) in its place, or post `posts/10-rename/` first to announce the new name.
