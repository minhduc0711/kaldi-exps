#!/usr/bin/env bash

lang_dir=data/local/dict

mkdir $lang_dir -p
# lexicon.txt
python local/prune_lexicon.py full_lexicon.txt data/train/text ${lang_dir}/lexicon.txt  # Keep only words that are present in the datset
# silence_phones.txt
echo -e "SIL\\nSPN" > "${lang_dir}/silence_phones.txt"
# nonsilence_phones.txt
tail -n +2 "${lang_dir}/lexicon.txt" | cut -d ' ' -f 2- | sed 's/ /\n/g' | sort -u > "${lang_dir}/nonsilence_phones.txt"
# optional_silence.txt
echo 'SIL' > "${lang_dir}/optional_silence.txt"