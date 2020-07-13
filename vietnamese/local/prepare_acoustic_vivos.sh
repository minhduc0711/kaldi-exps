#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
    echo "ERROR: $0"
    echo "USAGE: $0 <raw_data_dir> <output_dir>"
    exit 1
fi

raw_data_dir=$1
output_dir=$2

mkdir -p $output_dir

# check whether there are invalid words in transcripts
./local/verify_words.py --text $raw_data_dir/prompts.txt || exit 1;
# create "text" (utterance_id + transcript)
cp $raw_data_dir/prompts.txt $output_dir/text

for audio_dir in ${raw_data_dir}/waves/*; do
    speaker_id=$(basename ${audio_dir})

    for audio_path in ${audio_dir}/*.wav; do
        utt_id=$(basename ${audio_path} .wav)
        # create "wav.scp" (utt_id + path to audio file)
        echo "$utt_id $audio_path" >> ${output_dir}/wav.scp
        # create "utt2spk" (utterance_id + speaker_id)
        echo "$utt_id $speaker_id" >> ${output_dir}/utt2spk
    done
done

# sort entries + create spk2utt
utils/fix_data_dir.sh $output_dir || exit 1
