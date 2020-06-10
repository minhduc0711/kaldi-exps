from tinytag import TinyTag
from pathlib import Path

data_dir = Path("raw/dev-clean/")
s = 0
for fname in data_dir.glob("**/*.flac"):
    tag = TinyTag.get(fname)
    s += tag.duration
s /= 360
print(f"{s}h")