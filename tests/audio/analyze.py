"""Numerical review, NOT a listening test. Generates checked-in QA and waveforms."""
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'tests/audio/evidence'

def db(x): return round(20*math.log10(max(x,1e-10)),2)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    rows = []
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1530" viewBox="0 0 1000 1530">',
        '<rect width="1000" height="1530" fill="#101b2c"/>',
        '<text x="24" y="30" fill="white" font-size="20">Original combat SFX / PCM waveform / fixed amplitude scale ±1</text>']
    for index,path in enumerate(sorted((ROOT/'assets/audio').glob('*.wav'))):
        with wave.open(str(path)) as f:
            assert (f.getnchannels(),f.getsampwidth(),f.getframerate()) == (1,2,32000)
            raw = f.readframes(f.getnframes())
            samples = [v/32768 for v in struct.unpack('<'+'h'*(len(raw)//2),raw)]
        peak = max(map(abs,samples))
        rms = math.sqrt(sum(x*x for x in samples)/len(samples))
        audible = [i for i,x in enumerate(samples) if abs(x)>=10**(-60/20)]
        onset = audible[0]/32
        tail = (len(samples)-1-audible[-1])/32
        windows = [db(math.sqrt(sum(x*x for x in samples[i:i+320])/len(samples[i:i+320]))) for i in range(0,len(samples),320)]
        # FFmpeg oversamples for true peak; short-sample gated LUFS often -inf.
        proc = subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af','loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
        data = json.JSONDecoder().raw_decode(proc.stderr[proc.stderr.rfind('{'):])[0]
        row = dict(id=path.stem,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            duration_ms=round(len(samples)/32,2),sample_peak_dbfs=db(peak),rms_dbfs=db(rms),
            crest_db=round(db(peak)-db(rms),2),onset_ms=onset,tail_below_minus60_db_ms=tail,
            clipped_samples=sum(abs(x)>=.999 for x in samples),edge_samples=[samples[0],samples[-1]],
            max_adjacent_step=round(max(abs(b-a) for a,b in zip(samples,samples[1:])),4),
            envelope_10ms_dbfs=windows,ffmpeg_true_peak_dbtp=data['input_tp'],ffmpeg_integrated_lufs=data['input_i'])
        assert row['clipped_samples']==0 and -11 <= db(peak) <= -6
        assert onset<10 and tail<65 and row['edge_samples']==[0,0]
        assert row['max_adjacent_step']<.35 and float(data['input_tp']) < -5
        rows.append(row)
        y = 65+index*96
        svg.append(f'<text x="24" y="{y}" fill="#cee3ff" font-size="14">{path.stem} / {row["duration_ms"]} ms / peak {db(peak)} / RMS {db(rms)} dBFS</text>')
        svg.append(f'<path d="M 24 {y+34} H 970" stroke="#3b485c"/>')
        for pixel in range(940):
            chunk=samples[pixel*len(samples)//940:(pixel+1)*len(samples)//940]
            if chunk:
                svg.append(f'<path d="M {24+pixel} {y+34-max(chunk)*48:.2f} V {y+34-min(chunk)*48:.2f}" stroke="#68d8c7"/>')
    svg.append('</svg>')
    report={'listening_test':False,'method':'PCM16 sample checks, 10ms RMS envelope, FFmpeg loudnorm oversampled true peak. LUFS of very short transients can be -inf; RMS is primary basic level comparison, not perceptual loudness approval.',
        'files':rows,'total_bytes':sum(r['bytes'] for r in rows),'worst_coherent_8_voice_peak_dbfs':round(max(r['sample_peak_dbfs'] for r in rows)-14+20*math.log10(8),2)}
    (OUT/'signal-review.json').write_text(json.dumps(report,indent=2)+'\n')
    (OUT/'waveforms.svg').write_text('\n'.join(svg))
    print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
    for row in rows: print(row['id'],row['sample_peak_dbfs'],row['rms_dbfs'],row['onset_ms'],row['tail_below_minus60_db_ms'])

if __name__=='__main__':main()
