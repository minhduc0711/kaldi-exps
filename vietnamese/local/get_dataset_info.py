import argparse as ap
import wave
import contextlib
from pathlib import Path


def get_duration(fname):
    with contextlib.closing(wave.open(fname, 'r')) as f:
        frames = f.getnframes()
        rate = f.getframerate()
        duration = frames / float(rate)
    return duration


parser = ap.ArgumentParser()
parser.add_argument("data_dir", type=str)
args = parser.parse_args()

data_dir = Path(args.data_dir)
s = 0
cnt = 0
for fname in data_dir.glob("**/*.wav"):
    s += get_duration(str(fname))
    cnt += 1
hours = s / 3600
print(f"Number of utterances: {cnt}")
print(f"Total audio hours: {hours:.2f}h")
