#!/usr/bin/env bash

raw_data_dir=$1

if [ "$#" -ne 1 ]; then
    echo "ERROR: $0"
    echo "USAGE: $0 <raw_data_dir>"
    exit 1
fi

subset_name=`basename $raw_data_dir`
dest_dir=data/$subset_name
mkdir -p $dest_dir

# create "text" (utterance_id + transcript)
python3 local/verify_words.py --text $raw_data_dir/prompts.txt || exit 1;
cp $raw_data_dir/prompts.txt $dest_dir/text

for audio_dir in ${raw_data_dir}/waves/*; do
    speaker_id=$(basename ${audio_dir})

    for audio_path in ${audio_dir}/*.wav; do
        utt_id=$(basename ${audio_path} .wav)
        # create "wav.scp" (utt_id + path to audio file)
        echo "$utt_id $audio_path" >> ${dest_dir}/wav.scp
        # create "utt2spk" (utterance_id + speaker_id)
        echo "$utt_id $speaker_id" >> ${dest_dir}/utt2spk
    done
done

# sort entries + create spk2utt
utils/fix_data_dir.sh $dest_dir || exit 1