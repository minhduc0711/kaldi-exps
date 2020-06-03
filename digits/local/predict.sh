#!/usr/bin/bash

rm -r data/duc exp/tri1_online

# IMPORTANT NOTE: remember to match sampling rate first
# i.e.: sox -t wav one.wav -c 1 -r 8000 -t wav - > one_8k.wav 
# Prepare test data
. ~/miniconda3/etc/profile.d/conda.sh
conda activate speech-recognition
python local/prepare_test_data.py

# Decode
. ./path.sh
steps/online/prepare_online_decoding.sh data/train data/lang exp/tri1 exp/tri1_online || exit 1
steps/online/decode.sh --per-utt true --nj 1 exp/tri1/graph data/duc exp/tri1_online || exit 1

lattice-best-path "ark:gunzip -c exp/tri1_online/lat.1.gz|" ark,t:-| int2sym.pl -f 2- data/lang/words.txt | cat