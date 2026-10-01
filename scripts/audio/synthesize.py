"""Original deterministic layered synthesis. Python stdlib only; 32 kHz PCM16 mono.
No recordings/samples/plugins. Edit recipes below and rerun from any directory.
"""
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[2]
RATE = 32000
TAU = math.tau

def tone(length, start, end=None, decay=5, overtone=.15):
    end = start if end is None else end
    phase = 0.0
    out = []
    for i in range(round(length * RATE)):
        t = i / RATE
        f = end + (start - end) * math.exp(-5 * t / length)
        phase += TAU * f / RATE
        env = min(1, t / .003) * math.exp(-decay*t/length) * min(1, (length-t)/.022)
        out.append(env * (math.sin(phase) + overtone * math.sin(2.003 * phase)))
    return out

def air(length, center, seed, decay=5):
    # Stable narrow band biquad: shaped air texture, never raw white noise.
    rng = random.Random(seed)
    w = TAU * center / RATE
    alpha = math.sin(w) / 1.2
    b0, b2 = alpha/(1+alpha), -alpha/(1+alpha)
    a1, a2 = -2*math.cos(w)/(1+alpha), (1-alpha)/(1+alpha)
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for i in range(round(length*RATE)):
        t = i/RATE
        x = rng.uniform(-1,1)
        y = b0*x + b2*x2 - a1*y1 - a2*y2
        x2, x1, y2, y1 = x1, x, y1, y
        env = min(1,t/.009) * math.exp(-decay*t/length) * min(1,(length-t)/.035)
        out.append(y*env)
    return out

def layer(*parts):
    n = max(round(at*RATE)+len(samples) for at,gain,samples in parts)
    out = [0.0]*n
    for at,gain,samples in parts:
        offset = round(at*RATE)
        for i,x in enumerate(samples): out[i+offset] += gain*x
    return out

def chord(notes, duration, stagger=.035):
    return layer(*[(i*stagger, 1/(1+.15*i), tone(duration,n,decay=5,overtone=.08)) for i,n in enumerate(notes)])

def recipes():
    bank = {}
    for i in range(3):
        bank[f'sword_{i+1}'] = layer((0,.9,air(.18+i*.015,1100+i*140,101+i,3.8)),
            (0,.32,tone(.16,520+i*40,190+i*15,5,.06)))
    bank['hit'] = layer((0,1,tone(.17,260,100,6)),(0,.24,air(.12,1700,200)),(.007,.18,tone(.12,920,570,7)))
    bank['hit_heavy'] = layer((0,1,tone(.30,155,62,6)),(0,.30,air(.18,900,201)),(.01,.25,tone(.23,430,175,6)))
    bank['dash'] = layer((0,.9,air(.25,660,301,3.5)),(0,.32,tone(.21,310,125,4,.02)))
    bank['hurt'] = layer((0,1,tone(.26,355,190,4,.2)),(.015,.45,tone(.23,377,210,4,.1)),(0,.12,air(.12,700,401)))
    bank['enemy_die'] = layer((0,.8,tone(.42,360,70,5,.22)),(.04,.35,air(.3,480,402)),(.025,.3,tone(.3,780,130,6)))
    bank['q_thrust'] = layer((0,.8,air(.23,1900,501,4)),(0,.7,tone(.24,980,280,5,.12)),(.01,.4,tone(.19,170,75,6)))
    bank['e_overload'] = layer((0,.75,tone(.52,240,740,2,.12)),(.06,.35,tone(.47,360,1110,2,.1)),(.20,.6,chord([740,1110,1480],.31,.025)))
    bank['r_slam'] = layer((0,1,tone(.62,145,46,5,.22)),(0,.35,air(.27,700,601)),(.015,.45,tone(.45,520,120,5)),(.03,.25,tone(.55,830,220,6)))
    bank['ui_confirm'] = chord([660,990],.13,.045)
    bank['ui_reject'] = chord([260,195],.15,.065)
    bank['level_up'] = chord([523.25,659.25,783.99,1046.5],.40,.09)
    bank['settlement'] = layer((0,.65,chord([392,493.88,587.33],.48,.065)),(.25,.8,chord([523.25,659.25,783.99,1046.5],.52,.065)))
    return bank

def main():
    target = ROOT/'assets/audio'
    target.mkdir(parents=True,exist_ok=True)
    for name,samples in recipes().items():
        # Per asset headroom; runtime adds -14 dB and enforces 8 total voices.
        peak_db = -10 if name in ('ui_confirm','ui_reject') else -7 if name in ('r_slam','hit_heavy') else -9
        gain = 10**(peak_db/20)/max(abs(x) for x in samples)
        # Raised cosine edge fades, both endpoints exactly zero.
        fade = round(.002*RATE)
        for i in range(fade):
            samples[i] *= .5-.5*math.cos(math.pi*i/fade)
            samples[-1-i] *= .5-.5*math.cos(math.pi*i/fade)
        pcm = [round(max(-1,min(1,x*gain))*32767) for x in samples]
        with wave.open(str(target/f'{name}.wav'),'wb') as wav:
            wav.setparams((1,2,RATE,0,'NONE','not compressed'))
            wav.writeframes(struct.pack('<'+'h'*len(pcm),*pcm))
        print(name,len(pcm)/RATE,len(pcm)*2+44)

if __name__ == '__main__': main()
