from pathlib import Path

import numpy as np
import pandas as pd

audio_dir = Path("raw/free-spoken-digit-dataset/recordings")
digit_2_text = {
    "0": "ZERO",
    "1": "ONE",
    "2": "TWO",
    "3": "THREE",
    "4": "FOUR",
    "5": "FIVE",
    "6": "SIX",
    "7": "SEVEN",
    "8": "EIGHT",
    "9": "NINE",
}

# Extract various infos from filename
df = pd.DataFrame(data={"path": audio_dir.iterdir()})
# Deal w/ sorting problems in kaldi
def make_utter_id(p):
    names = p.stem.split("_")
    return "-".join([names[1], names[0], names[2]])
df["utter_id"] = df["path"].apply(make_utter_id)
df["label"] = df["path"].apply(lambda x: str(x.stem).split("_")[0])
df["speaker"] = df["path"].apply(lambda x: str(x.stem).split("_")[1])
df["subset"] = None  # Placeholder col for train/test subset tag

# Split dataset into train/test
test_ratio = 0.2
for label, speaker in df.groupby(["label", "speaker"]).groups.keys():
    num_total = len(df.loc[(df["label"] == label) & (df["speaker"] == speaker)])
    num_test = int(num_total * 0.2)
    num_train = num_total - num_test
    subset_tags = ["train"] * num_train + ["test"] * num_test
    np.random.shuffle(subset_tags)
    df.loc[(df["label"] == label) & (df["speaker"] == speaker), "subset"] = subset_tags
train_df = df[df["subset"] == "train"]
test_df = df[df["subset"] == "test"]

# Create necessary metadata files for each data subset
dest_dirs = [Path("data/train"), Path("data/test")]
for audio_df, dest_dir in zip([train_df, test_df], dest_dirs):
    dest_dir.mkdir(exist_ok=True, parents=True)
    # Create "text" (utterance id + transcript)
    text_df = pd.DataFrame(data={"0": audio_df["utter_id"],
                                 "1": [digit_2_text[label] for label in audio_df["label"]]})
    text_df.to_csv(dest_dir / "text", sep=" ", index=False, header=False)

    # Create "wav.scp" (utterance id + audio path)
    wav_scp_df = pd.DataFrame(data={"0": audio_df["utter_id"],
                                    "1": audio_df["path"]})
    wav_scp_df.to_csv(dest_dir / "wav.scp", sep=" ", index=False, header=False)

    # Create "utt2spk" (utterance id + speaker id)
    utt2spk_df = pd.DataFrame(data={"0": audio_df["utter_id"],
                                    "1": audio_df["speaker"]})
    utt2spk_df.to_csv(dest_dir / "utt2spk", sep=" ", index=False, header=False)
