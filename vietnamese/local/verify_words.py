import sys
import argparse as ap

parser = ap.ArgumentParser()
parser.add_argument("--text", help="path to the transcript")
args = parser.parse_args()

# Collect all words in the transcript
present_words = set()
with open(args.text) as f:
    for line in f.readlines():
        _, transcript = line.strip().split(" ", 1)
        present_words.update(transcript.split(" "))
present_words = sorted(list(present_words))

# Verify
invalid_words = [word for word in present_words if not word.isalpha()]
if len(invalid_words) > 0:
    invalid_str = " ".join(invalid_words)
    print(f"Found invalid words in transcript: {invalid_str}")
    sys.exit(1)
