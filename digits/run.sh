#!/usr/bin/bash

train_cmd="utils/run.pl"
decode_cmd="utils/run.pl"

# Clean dirs
rm -rf data exp mfcc

echo ============================================================================
echo "                        Acoustic data prep                                "
echo ============================================================================
. ~/miniconda3/etc/profile.d/conda.sh
conda activate speech-recognition
python local/prepare_acoustic.py || exit 1

echo ============================================================================
echo "                        Language data prep                                "
echo ============================================================================

local/prepare_dict.sh || exit 1

# Go back to python2 (Kaldi defaults)
. ./path.sh
utils/prepare_lang.sh --position-dependent-phones false \
    data/local/dict '<UNK>' data/local/lang data/lang

echo ============================================================================
echo "                              Building LM                                 "
echo ============================================================================
cut -d' ' -f2- data/train/text > data/local/corpus.txt
local/prepare_lm.sh 

echo ============================================================================
echo "                      extracting mfcc features                            "
echo ============================================================================
mfccdir=mfcc
for x in train test; do
    utils/fix_data_dir.sh data/$x  # Sort entries in acoustic data files
    steps/make_mfcc.sh data/$x exp/make_mfcc/$x $mfccdir
    steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
done

nj=4

echo ============================================================================
echo "                      training monophone model                            "
echo ============================================================================
steps/train_mono.sh --boost-silence 1.25 --cmd "$train_cmd" \
    data/train data/lang exp/mono || exit 1

echo ============================================================================
echo "                      decoding monophone model                            "
echo ============================================================================
utils/mkgraph.sh --mono data/lang exp/mono exp/mono/graph || exit 1
steps/decode.sh --config conf/decode.config --cmd "$decode_cmd" exp/mono/graph data/test exp/mono/decode

echo
echo "===== MONO ALIGNMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/mono exp/mono_ali || exit 1
echo
echo "===== TRI1 (first triphone pass) TRAINING ====="
echo
steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 data/train data/lang exp/mono_ali exp/tri1 || exit 1
echo
echo "===== TRI1 (first triphone pass) DECODING ====="
echo
utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1/graph data/test exp/tri1/decode
echo
echo "===== run.sh script is finished ====="
echo