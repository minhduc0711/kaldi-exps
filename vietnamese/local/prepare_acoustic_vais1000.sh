#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
    echo "ERROR: $0"
    echo "USAGE: $0 <raw_data_dir> <output_dir>"
    exit 1
fi

raw_data_dir=$1
output_dir=$2

mkdir -p $output_dir

# create "text" (utterance_id + transcript)
./local/fix_vais_transcript.py $raw_data_dir/metadata.csv $output_dir/text
./local/verify_words.py --text text || exit 1;

for audio_path in ${raw_data_dir}/wavs/*; do
    utt_id=$(basename ${audio_path} .wav)
    # no speaker info
    speaker_id=$utt_id
    # create "wav.scp" (utt_id + path to audio file)
    echo "$utt_id $audio_path" >> ${output_dir}/wav.scp
    # create "utt2spk" (utterance_id + speaker_id)
    echo "$utt_id $speaker_id" >> ${output_dir}/utt2spk
done

# sort entries + create spk2utt
utils/fix_data_dir.sh $output_dir || exit 1
