import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ.get('STIKKA_ROOT', os.path.join(HERE, '..', '..'))  # repo root (store/instagram/gen.py)
OUT = os.environ.get('IG_OUT', HERE)
F = SRC + '/assets/fonts/'
HEAD = F + 'SairaExtraCondensed-Bold.ttf'
BODY = F + 'Saira-Medium.ttf'
SEMI = F + 'Saira-SemiBold.ttf'
W, H = 1080, 1350
BG = (0, 0, 0)
WHITE = (255, 255, 255)
GREY = (160, 160, 160)
DIM = (110, 110, 110)
RED = (255, 59, 48)

ICON = Image.open(SRC + '/tool/icon/app-icon.png').convert('RGB')


def font(p, s):
    return ImageFont.truetype(p, s)


def wrap(d, text, f, maxw):
    lines = []
    for para in text.split('\n'):
        cur = ''
        for w in para.split(' '):
            t = (cur + ' ' + w).strip()
            if d.textlength(t, font=f) <= maxw:
                cur = t
            else:
                lines.append(cur)
                cur = w
        lines.append(cur)
    return lines


def text_block(d, x, y, text, f, fill, maxw, lh, center=False):
    for line in wrap(d, text, f, maxw):
        if center:
            d.text((W / 2, y), line, font=f, fill=fill, anchor='ma')
        else:
            d.text((x, y), line, font=f, fill=fill)
        y += lh
    return y


def wordmark(img, d):
    ic = ICON.resize((56, 56), Image.LANCZOS)
    img.paste(ic, (72, 58))
    d.text((138, 86), 'Stikka', font=font(HEAD, 44), fill=GREY, anchor='lm')


def load_screen(name):
    """Return the phone screen without the store padding."""
    p = SRC + '/' + name
    im = Image.open(p).convert('RGB')
    if im.size == (1560, 2772):  # store screenshots: padded 144px per side
        im = im.crop((144, 0, 1416, 2772))
    return im


def rounded_mask(size, r, bottom=True):
    m = Image.new('L', size, 0)
    md = ImageDraw.Draw(m)
    h = size[1] if bottom else size[1] + r
    md.rounded_rectangle((0, 0, size[0] - 1, h - 1), r, fill=255)
    return m


def paste_card(img, scr, box, y0=0, bleed=True):
    """Scale the screen to the box width and show a window from y0, bleeding off the bottom."""
    bx, by, bw, bh = box
    s = bw / scr.width
    win_h = int(bh / s)
    y0 = max(0, y0)
    crop = Image.new('RGB', (scr.width, win_h), scr.getpixel((scr.width // 2, scr.height - 5)))
    part = scr.crop((0, y0, scr.width, min(scr.height, y0 + win_h)))
    crop.paste(part, (0, 0))
    crop = crop.resize((bw, bh), Image.LANCZOS)
    r = 44
    mask = rounded_mask((bw, bh), r, bottom=not bleed)
    d = ImageDraw.Draw(img)
    # border
    d.rounded_rectangle((bx - 3, by - 3, bx + bw + 2, by + bh + (r if bleed else 2)), r + 3, fill=(52, 52, 52))
    img.paste(crop, (bx, by), mask)


def full_screen(img, scr, box):
    bx, by, bw, bh = box
    s = min(bw / scr.width, bh / scr.height)
    w, h = int(scr.width * s), int(scr.height * s)
    im = scr.resize((w, h), Image.LANCZOS)
    x = bx + (bw - w) // 2
    y = by + (bh - h) // 2
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x - 3, y - 3, x + w + 2, y + h + 2), 36, fill=(52, 52, 52))
    img.paste(im, (x, y), rounded_mask((w, h), 34))


def header(img, d, head, sub, hs=92):
    wordmark(img, d)
    y = 168
    y = text_block(d, 72, y, head, font(HEAD, hs), WHITE, W - 144, int(hs * 0.98))
    if sub:
        y += 30
        y = text_block(d, 72, y, sub, font(BODY, 34), GREY, W - 144, 48)
    return y


def slide_screen(head, sub, src, y0=0):
    img = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(img)
    y = header(img, d, head, sub)
    top = y + 44
    paste_card(img, load_screen(src), (110, top, 860, H - top), y0)
    return img


def slide_pair(head, sub, a, b):
    img = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(img)
    y = header(img, d, head, sub)
    top = y + 50
    bh = H - top - 60
    full_screen(img, load_screen(a), (72, top, 450, bh))
    full_screen(img, load_screen(b), (558, top, 450, bh))
    return img


def slide_text(head, sub, hs=150):
    img = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(img)
    wordmark(img, d)
    fh = font(HEAD, hs)
    fb = font(BODY, 40)
    hl = wrap(d, head, fh, W - 144)
    sl = wrap(d, sub, fb, W - 180) if sub else []
    total = len(hl) * hs * 0.98 + (40 + len(sl) * 58 if sl else 0)
    y = (H - total) / 2
    for line in hl:
        d.text((72, y), line, font=fh, fill=WHITE)
        y += hs * 0.98
    d.rectangle((72, y + 50, 72 + 90, y + 58), fill=RED)
    y += 100
    for line in sl:
        d.text((72, y), line, font=fb, fill=GREY)
        y += 58
    return img


def slide_cta():
    img = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(img)
    ic = ICON.resize((300, 300), Image.LANCZOS)
    img.paste(ic, ((W - 300) // 2, 150))
    d.text((W / 2, 500), 'Free on Android', font=font(HEAD, 120), fill=WHITE, anchor='ma')
    d.text((W / 2, 640), 'The test is open. Join in 2 steps:', font=font(BODY, 38), fill=GREY, anchor='ma')
    steps = ['Join the Google Group  metra-testers', 'Open the Play testing link and install']
    y = 750
    for i, s in enumerate(steps, 1):
        d.rounded_rectangle((110, y, W - 110, y + 120), 28, fill=(28, 28, 28))
        d.ellipse((140, y + 30, 200, y + 90), fill=RED)
        d.text((170, y + 60), str(i), font=font(SEMI, 34), fill=WHITE, anchor='mm')
        d.text((230, y + 60), s, font=font(BODY, 36), fill=WHITE, anchor='lm')
        y += 150
    d.text((W / 2, 1110), 'Both links: in bio', font=font(HEAD, 64), fill=RED, anchor='ma')
    d.text((W / 2, 1210), 'No ads · No account · No tracking', font=font(BODY, 32), fill=DIM, anchor='ma')
    return img


S = 'store/screenshots/'
D = 'docs/design/screens/'

POSTS = {
    '01-meet-stikka': [
        ('s', 'A metronome built by a drummer.', 'Free, no ads. For the practice room, rehearsal and the stage.', S + '01-heads-up.png', 120),
        ('s', 'Whole songs, not just a click.', 'Parts, tempo changes and time signatures. One tap plays it all.', S + '02-parts-page.png', 120),
        ('s', 'Made for the stage.', 'Big buttons, the next song one tap away, and a hold to exit.', S + '03-stage-mode.png', 120),
        ('cta',),
    ],
    '02-song-parts': [
        ('s', 'Your song changes tempo. Your click should too.', None, S + '02-parts-page.png', 120),
        ('s', 'Build a song from parts.', 'Intro, verse, chorus, a one-bar 2/4 break. Each part has its own length, tempo and time signature.', S + '02-parts-page.png', 120),
        ('s', 'Speed up across a part.', 'Gradual tempo changes: the chorus goes from 128 to 140, smoothly.', S + '02-parts-page.png', 1385),
        ('s', 'Odd meters? Covered.', '1 to 16 beats over 4 or 8, subdivisions, accents and polyrhythms.', S + '07-rhythm-panel.png', 640),
        ('cta',),
    ],
    '03-heads-up': [
        ('s', 'Never miss the break again.', 'Stikka warns you before every part change.', S + '01-heads-up.png', 120),
        ('s', 'A warning, then a countdown.', '"Break in 2 bars", then beat by beat. A short break after a long verse won\'t catch you.', S + '03-stage-mode.png', 760),
        ('s', 'Lost your place? Tap the map.', 'Tap any part on the song map to jump straight there.', D + 'jump-to-part-stage.png', 820),
        ('cta',),
    ],
    '04-stage-mode': [
        ('s', 'Big screen. Big buttons. No accidents.', 'Stage mode shows only what you need on stage.', S + '03-stage-mode.png', 120),
        ('s', 'Next song, one tap.', 'Big Previous, Next and Start. Or use the lock screen, or a Bluetooth page-turner pedal.', S + '03-stage-mode.png', 1560),
        ('s', 'Hold to exit.', 'A stray touch never takes you out. The count-in shows right on the Stop button.', D + 'count-in-stop-stage-115.png', 120),
        ('cta',),
    ],
    '05-setlists-sharing': [
        ('s', 'The whole gig in your pocket.', 'Save songs with their tempo, rhythm and parts, then build setlists.', S + '04-set-list.png', 420),
        ('s', 'Send the set to the band.', 'Share the running order with tempos and time signatures, in any app.', D + 'share-menu-set-115.png', 900),
        ('s', 'Or send the songs themselves.', 'Export a set with every song and its parts. Your bandmates import it into their Stikka.', D + 'share-pick-mode-115.png', 640),
        ('cta',),
    ],
    '06-practice-speed': [
        ('s', 'Learn it at 80%. Play it at 100%.', None, D + 'practice-speed-main-playing-115.png', 150),
        ('s', 'Slow the whole song down.', 'Every part and every tempo change, in proportion. A little faster each time it loops, up to 100%.', D + 'practice-speed-sheet-115.png', 380),
        ('s', 'On stage too.', 'The 80% tag sits right under the tempo, so you always know what you\'re playing.', D + 'practice-speed-stage-115.png', 790),
        ('cta',),
    ],
    '07-count-in': [
        ('s', 'Count yourself in.', 'A 1 or 2 bar count-in, shown on screen as it counts.', S + '06-count-in-parts-page.png', 120),
        ('s', 'Speed up as you go.', 'Add a few bpm every few bars, up to a target tempo.', S + '05-when-i-press-start.png', 430),
        ('cta',),
    ],
    '08-tuner': [
        ('p', 'A tuner for the whole band.', 'Big note name, cents off, a smooth needle.', D + 'tuner-in-tune-v2-115.png', D + 'tuner-sharp-v2-115.png'),
        ('s', 'Set your A4.', 'From 430 to 450 Hz. The mic is used only while the tuner is open. Nothing is recorded or sent.', D + 'tuner-sharp-v2-115.png', 1470),
        ('cta',),
    ],
    '09-free-private': [
        ('t', 'No ads. No account. No tracking.', 'Stikka has no internet access. Your songs stay on your phone.'),
        ('t', 'Why free?', 'I\'m a drummer. I wanted a metronome that just works, in the practice room and on stage. So I built one.', 130),
        ('s', 'Dark or Daylight.', 'High-contrast Stage Black, plus a Daylight theme for bright rooms.', S + '08-daylight.png', 120),
        ('cta',),
    ],
}


def render(spec):
    k = spec[0]
    if k == 's':
        return slide_screen(*spec[1:])
    if k == 'p':
        return slide_pair(*spec[1:])
    if k == 't':
        return slide_text(*spec[1:])
    return slide_cta()


def profile():
    os.makedirs(OUT + '/profile', exist_ok=True)
    img = Image.new('RGB', (1080, 1080), BG)
    ic = ICON.resize((880, 880), Image.LANCZOS)
    img.paste(ic, (100, 100))
    img.save(OUT + '/profile/profile-picture.png')
    for i, word in enumerate(['Join', 'Parts', 'Stage', 'Sets', 'Practice', 'Tuner'], 1):
        # Square, so Instagram's circle takes the whole image with no zooming.
        c = Image.new('RGB', (1080, 1080), BG)
        d = ImageDraw.Draw(c)
        size = 330
        while d.textlength(word, font=font(HEAD, size)) > 720:
            size -= 5
        d.rounded_rectangle((540 - 22, 170, 540 + 22, 400), 22, fill=RED)
        d.text((540, 690), word, font=font(HEAD, size), fill=WHITE, anchor='mm')
        c.save(f'{OUT}/profile/highlight-{i}-{word.lower()}.png')


if __name__ == '__main__':
    profile()
    for name, slides in POSTS.items():
        os.makedirs(f'{OUT}/posts/{name}', exist_ok=True)
        for i, s in enumerate(slides, 1):
            render(s).save(f'{OUT}/posts/{name}/{i}.png', optimize=True)
    print('ok')


def story_screen(head, sub, src, y0=0):
    """9:16 story. Text starts below the top bar (~250px); the screen fills the rest and runs off the bottom."""
    c = Image.new('RGB', (1080, 1920), BG)
    d = ImageDraw.Draw(c)
    ic = ICON.resize((60, 60), Image.LANCZOS)
    c.paste(ic, (72, 230))
    d.text((142, 260), 'Stikka', font=font(HEAD, 48), fill=GREY, anchor='lm')
    y = text_block(d, 72, 340, head, font(HEAD, 110), WHITE, W - 144, 108)
    if sub:
        y += 34
        y = text_block(d, 72, y, sub, font(BODY, 38), GREY, W - 144, 54)
    top = y + 56
    paste_card(c, load_screen(src), (90, top, 900, 1920 - top), y0)
    return c


def story_join():
    c = Image.new('RGB', (1080, 1920), BG)
    d = ImageDraw.Draw(c)
    ic = ICON.resize((280, 280), Image.LANCZOS)
    c.paste(ic, ((1080 - 280) // 2, 300))
    d.text((540, 640), 'Free on Android', font=font(HEAD, 130), fill=WHITE, anchor='ma')
    d.text((540, 800), 'The test is open. Join in 2 steps:', font=font(BODY, 40), fill=GREY, anchor='ma')
    y = 900
    for i, s in enumerate(['Join the Google Group  metra-testers', 'Open the Play testing link and install'], 1):
        d.rounded_rectangle((100, y, 980, y + 124), 28, fill=(28, 28, 28))
        d.ellipse((130, y + 32, 190, y + 92), fill=RED)
        d.text((160, y + 62), str(i), font=font(SEMI, 34), fill=WHITE, anchor='mm')
        d.text((220, y + 62), s, font=font(BODY, 36), fill=WHITE, anchor='lm')
        y += 154
    d.text((540, 1250), 'Tap the link to start', font=font(HEAD, 64), fill=RED, anchor='ma')
    # 1360–1600 left empty for the link sticker
    d.text((540, 1640), 'No ads · No account · No tracking', font=font(BODY, 32), fill=DIM, anchor='ma')
    return c


STORIES = {
    'story-1-join': None,
    'story-2-parts': '02-song-parts',
    'story-3-stage': '04-stage-mode',
    'story-4-sets': '05-setlists-sharing',
    'story-5-practice': '06-practice-speed',
    'story-6-tuner': '08-tuner',
}


def stories():
    os.makedirs(OUT + '/stories', exist_ok=True)
    for name, post in STORIES.items():
        if post is None:
            img = story_join()
        else:
            spec = POSTS[post][0]
            img = story_screen(spec[1], spec[2], spec[3], 0 if spec[0] == 'p' else spec[4])
        img.save(f'{OUT}/stories/{name}.png', optimize=True)


if __name__ == '__main__':
    stories()


def fb_cover():
    """Facebook Page cover: 1640x624 (2x of 820x312). Content kept in the centre 1280x624 (mobile crop)."""
    os.makedirs(OUT + '/facebook', exist_ok=True)
    c = Image.new('RGB', (1640, 624), BG)
    d = ImageDraw.Draw(c)
    # left half of the safe zone: name + tagline
    d.text((580, 300), 'Stikka', font=font(HEAD, 220), fill=WHITE, anchor='ms')
    d.text((580, 380), 'From practice room to stage', font=font(BODY, 36), fill=GREY, anchor='ma')
    d.text((580, 450), 'Free metronome for Android · No ads', font=font(BODY, 30), fill=DIM, anchor='ma')
    # right half: tempo ruler like the store graphic, centred on 120
    mid, px, top = 1110, 16, 180
    for b in range(106, 135):
        x = mid + (b - 120) * px
        major = b % 5 == 0
        y0 = top + (0 if major else 40)
        d.rectangle((x - 2, y0, x + 2, top + 130), fill=(140, 140, 140) if major else (58, 58, 58))
        if b % 10 == 0:
            d.text((x, top + 200), str(b), font=font(HEAD, 48), fill=WHITE if b == 120 else (140, 140, 140), anchor='ms')
    d.rounded_rectangle((mid - 4, top - 50, mid + 4, top + 150), 4, fill=RED)
    c.save(OUT + '/facebook/page-cover.png')


if __name__ == '__main__':
    fb_cover()
