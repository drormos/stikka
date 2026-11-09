"""Instagram reels (1080x1920 H.264) from scrcpy screen recordings.

Usage: python3 store/instagram/reels.py r2 <recording.mp4>
Needs Pillow and ffmpeg. Text sits between y=250 and y=1670 (the story safe zone).
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

from gen import BG, BODY, DIM, GREY, HEAD, ICON, RED, SEMI, WHITE, font

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 1080, 1920
STATUS_BAR = 130  # phone px cropped off the top (OnePlus ignores demo mode's notification hiding)
SCREEN = (607, 1260, 430)  # width, height, top of the screen on the reel
CARD = (40, 40, 40)


def background(path):
    """Black frame with the wordmark and a thin outline around the screen."""
    c = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(c)
    c.paste(ICON.resize((60, 60), Image.LANCZOS), (72, 250))
    d.text((142, 280), 'Stikka', font=font(HEAD, 48), fill=GREY, anchor='lm')
    sw, sh, top = SCREEN
    x = (W - sw) // 2
    d.rounded_rectangle((x - 3, top - 3, x + sw + 2, top + sh + 2), 39, outline=CARD, width=3)
    c.save(path)


def mask(path):
    sw, sh, _ = SCREEN
    m = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, sw - 1, sh - 1), 36, fill=255)
    m.save(path)


def caption(path, text):
    c = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(c).text((W / 2, 335), text, font=font(HEAD, 80), fill=WHITE, anchor='ma')
    c.save(path)


def end_card(path):
    """The join slide from the stories, with the CTA the captions use."""
    c = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(c)
    c.paste(ICON.resize((280, 280), Image.LANCZOS), ((W - 280) // 2, 300))
    d.text((540, 640), 'Free on Android', font=font(HEAD, 130), fill=WHITE, anchor='ma')
    d.text((540, 800), 'The test is open. Join in 2 steps:', font=font(BODY, 40), fill=GREY, anchor='ma')
    y = 900
    for i, s in enumerate(['Join the Google Group  metra-testers', 'Open the Play testing link and install'], 1):
        d.rounded_rectangle((100, y, 980, y + 124), 28, fill=(28, 28, 28))
        d.ellipse((130, y + 32, 190, y + 92), fill=RED)
        d.text((160, y + 62), str(i), font=font(SEMI, 34), fill=WHITE, anchor='mm')
        d.text((220, y + 62), s, font=font(BODY, 36), fill=WHITE, anchor='lm')
        y += 154
    d.text((540, 1250), 'Links in the first comment', font=font(HEAD, 64), fill=RED, anchor='ma')
    d.text((540, 1400), 'No ads · No account · No tracking', font=font(BODY, 32), fill=DIM, anchor='ma')
    c.save(path)


# R2 "Set up tonight's gig in 30 seconds". Segments of the recording:
# (start s, end s, speed). The click is never sped up, and the stage cut
# jumps whole bars (9 bars at 120 BPM = 18 s) so the beat stays even.
R2_SEGMENTS = [
    (0.5, 7.8, 2.0),     # Songs tab, pick Glass Harbor
    (7.8, 11.8, 1.0),    # its parts
    (11.8, 27.8, 2.0),   # new set "Tonight", add 3 songs
    (27.8, 34.625, 1.0),  # stage mode, Start, count-in, "Verse in 4 bars"
    (52.625, 60.5, 1.0),  # "Break in 2 bars", the break, the chorus speeds up
]
# (caption, start, end) in reel seconds
R2_CAPTIONS = [
    ("Tonight's gig in 30 seconds", 0, 3.65),
    ('Your song, part by part', 3.65, 7.65),
    ("Add it to tonight's set", 7.65, 15.65),
    ('Stage mode. One tap.', 15.65, 22.475),
    ('A heads-up before every change', 22.475, 30.35),
]
END_SECONDS = 2.5
GAIN_DB = 12  # scrcpy captures the click at about -14 dBFS peak


def run(cmd):
    subprocess.run(cmd, check=True)


def build(name, src, segments, captions):
    tmp = tempfile.mkdtemp()
    bg, msk, end = (f'{tmp}/{n}.png' for n in ('bg', 'mask', 'end'))
    background(bg)
    mask(msk)
    end_card(end)
    caps = []
    for i, (text, a, b) in enumerate(captions):
        p = f'{tmp}/cap{i}.png'
        caption(p, text)
        caps.append((p, a, b))

    sw, sh, top = SCREEN
    f = []
    for i, (a, b, speed) in enumerate(segments):
        f.append(f'[0:v]trim={a}:{b},setpts=(PTS-STARTPTS)/{speed},fps=30[v{i}]')
        tempo = f',atempo={speed}' if speed != 1 else ''
        f.append(f'[0:a]atrim={a}:{b},asetpts=PTS-STARTPTS{tempo}[a{i}]')
    n = len(segments)
    f.append(''.join(f'[v{i}][a{i}]' for i in range(n)) + f'concat=n={n}:v=1:a=1[cv][ca]')
    f.append(f'[cv]crop=iw:ih-{STATUS_BAR}:0:{STATUS_BAR},scale={sw}:{sh}:flags=lanczos,format=rgba[sc]')
    f.append('[2:v]format=gray[m]')
    f.append('[sc][m]alphamerge[scr]')
    f.append(f'[1:v][scr]overlay=x={(W - sw) // 2}:y={top}:shortest=1[l0]')
    for i, (_, a, b) in enumerate(caps):
        f.append(f'[l{i}][{3 + i}:v]overlay=shortest=1:enable=\'between(t,{a},{b})\'[l{i + 1}]')
    main_len = sum((b - a) / s for a, b, s in segments)
    f.append(f'[l{len(caps)}]format=yuv420p[main]')
    f.append(f'[ca]volume={GAIN_DB}dB,afade=t=out:st={main_len - 0.6}:d=0.6,'
             f'apad=whole_dur={main_len + END_SECONDS}[aout]')
    e = 3 + len(caps)
    f.append(f'[{e}:v]fps=30,format=yuv420p,trim=duration={END_SECONDS}[endv]')
    f.append('[main][endv]concat=n=2:v=1:a=0[vout]')

    # Every looped image gets a length: an endless one keeps alphamerge and concat waiting.
    still = lambda p, t: ['-loop', '1', '-framerate', '30', '-t', f'{t:.3f}', '-i', p]
    inputs = ['-i', src, *still(bg, main_len), *still(msk, main_len)]
    for p, _, _ in caps:
        inputs += still(p, main_len)
    inputs += still(end, END_SECONDS)
    out = f'{HERE}/reels/{name}.mp4'
    os.makedirs(os.path.dirname(out), exist_ok=True)
    run(['ffmpeg', '-v', 'error', '-y', *inputs, '-filter_complex', ';'.join(f),
         '-map', '[vout]', '-map', '[aout]',
         '-c:v', 'libx264', '-profile:v', 'high', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p',
         '-r', '30', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-movflags', '+faststart',
         '-t', f'{main_len + END_SECONDS:.3f}', out])  # the looped images never end on their own
    print(out)


if __name__ == '__main__':
    which, src = sys.argv[1], sys.argv[2]
    if which == 'r2':
        build('r2-tonights-gig', src, R2_SEGMENTS, R2_CAPTIONS)
    else:
        sys.exit(f'Unknown reel {which}')
