#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
    echo "ERROR: $0"
    echo "USAGE: $0 <train_data_dir> <dest_dir>"
    exit 1
fi

train_data_dir=$1
dest_dir=$2

mkdir -p $dest_dir

# Build lexicon
./local/build_lexicon.py --text $train_data_dir/text --dst $dest_dir/lexicon.txt

# silence_phones.txt
echo -e "SIL\\nSPN" > "${dest_dir}/silence_phones.txt"
# nonsilence_phones.txt
tail -n +2 "${dest_dir}/lexicon.txt" | cut -d ' ' -f 2- | sed 's/ /\n/g' | sort -u > "${dest_dir}/nonsilence_phones.txt"
# optional_silence.txt
echo 'SIL' > "${dest_dir}/optional_silence.txt"
