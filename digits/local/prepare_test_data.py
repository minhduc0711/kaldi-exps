from pathlib import Path

test_audio_dir = Path("duc_recordings/")
output_dir = Path("data/duc")
output_dir.mkdir(parents=True, exist_ok=True)
with open(output_dir / "wav.scp", "w") as f, \
        open(output_dir / "utt2spk", "w") as g:
    for audio_path in test_audio_dir.iterdir():
        f.write(f"{audio_path.stem} {str(audio_path)}\n")
        g.write(f"{audio_path.stem} duc\n")
    