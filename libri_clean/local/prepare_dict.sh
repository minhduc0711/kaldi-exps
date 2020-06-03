#!/usr/bin/env bash

dest_dir=data/local/dict
mkdir -p $dest_dir

# Prepare lexicon.txt
if [ ! -f external/librispeech-lexicon.txt ];then
    wget http://www.openslr.org/resources/11/librispeech-lexicon.txt -P external
fi

# . ~/miniconda3/etc/profile.d/conda.sh
# conda activate speech-recognition || exit 1
# echo `which python`
~/miniconda3/envs/speech-recognition/bin/python local/prune_lexicon.py \
        --src external/librispeech-lexicon.txt \
        --dst ${dest_dir}/lexicon.txt \
        --trans data/train-clean-100/text 
# cp external/librispeech-lexicon.txt ${dest_dir}/lexicon.txt

# silence_phones.txt
echo -e "SIL\\nSPN" > "${dest_dir}/silence_phones.txt"
# nonsilence_phones.txt
tail -n +2 "${dest_dir}/lexicon.txt" | cut -d ' ' -f 2- | sed 's/ /\n/g' | sort -u > "${dest_dir}/nonsilence_phones.txt"
# optional_silence.txt
echo 'SIL' > "${dest_dir}/optional_silence.txt"