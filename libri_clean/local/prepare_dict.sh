#!/usr/bin/env bash

train_data_dir=$1

if [ "$#" -ne 1 ]; then
    echo "ERROR: $0"
    echo "USAGE: $0 <train_data_dir>"
    exit 1
fi

dest_dir=data/local/dict
mkdir -p $dest_dir

# Prepare lexicon.txt
if [ ! -f external/librispeech-lexicon.txt ];then
    wget http://www.openslr.org/resources/11/librispeech-lexicon.txt -P external
fi

# . ~/miniconda3/etc/profile.d/conda.sh
# conda activate speech-recognition || exit 1
# echo `which python`
python3 local/prune_lexicon.py \
        --src external/librispeech-lexicon.txt \
        --dst ${dest_dir}/lexicon.txt \
        --trans ${train_data_dir}/text 

# silence_phones.txt
echo -e "SIL\\nSPN" > "${dest_dir}/silence_phones.txt"
# nonsilence_phones.txt
tail -n +2 "${dest_dir}/lexicon.txt" | cut -d ' ' -f 2- | sed 's/ /\n/g' | sort -u > "${dest_dir}/nonsilence_phones.txt"
# optional_silence.txt
echo 'SIL' > "${dest_dir}/optional_silence.txt"