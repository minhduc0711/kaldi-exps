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

for audio_dir in ${raw_data_dir}/LibriSpeech/${subset_name}/*/*; do
    # create "text" (utterance_id + transcript)
    cat `find ${audio_dir}/*.txt` >> ${dest_dir}/text

    for audio_path in ${audio_dir}/*.flac; do
        utt_id=`basename ${audio_path} .flac`
        # convert flac to wav on the fly in "wav.scp" 
        echo "$utt_id sox $audio_path -r 16000 -t wav - |" >> ${dest_dir}/wav.scp
        # create "utt2spk" (utterance_id + speaker_id)
        IFS='-' read -ra arr <<< $utt_id
        echo "$utt_id ${arr[0]}" >> ${dest_dir}/utt2spk
    done
done

# sort entries + create spk2utt
utils/fix_data_dir.sh $dest_dir || exit 1