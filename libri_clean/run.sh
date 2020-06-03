#!/usr/bin/env bash
. ./cmd.sh
. ./path.sh

nj=4

# # Clean dirs
# rm -rf data exp mfcc

# Prepare acoustic data
local/prepare_acoustic.sh || exit 1

# Prepare data/local/dict
./local/prepare_dict.sh || exit 1
utils/prepare_lang.sh --position-dependent-phones false \
    data/local/dict '<UNK>' data/local/lang data/lang || exit 1

# Prepare LM
local/prepare_lm.sh || exit 1

# Extract MFCC features
mfccdir=mfcc
for x in train-clean-100 dev-clean; do
    steps/make_mfcc.sh --nj $nj data/$x exp/make_mfcc/$x $mfccdir
    steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
done

# Train monophone model
steps/train_mono.sh --nj $nj --boost-silence 1.25 --cmd "$train_cmd" \
    data/train-clean-100 data/lang exp/mono || exit 1