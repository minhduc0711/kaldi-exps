#!/usr/bin/env bash

if [ "$#" -ne 3 ]; then
  echo "USAGE: $0 <model_dir> <test_acoustic_dir> <num_procs>"
  exit 1
fi

model_dir=$1
test_acoustic_dir=$2
num_procs=$3

. ./cmd.sh
. ./path.sh
. local/util_funcs.sh

### STAGES
##
#
prep_lang_test=1
compile_graph=1
decode_test=1
#
##
###

# Dirs
data_dir=data
exp_dir=exp
mfcc_dir=mfcc
lm_dir=lm

if [ "$prep_lang_test" -eq "1" ]; then

  printf "\n####==============####\n"
  printf "#### PREPARING LM ####\n"
  printf "####==============####\n\n"

  prompt_rm_dir data/lang{"", _test_{tgmed,tglarge}}/

  # decode using the trained model with pronunciation and silence probabilities
  steps/get_prons.sh --cmd "$decode_cmd" \
        data/train data/lang_nosp $model_dir

  utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict_nosp \
    $model_dir/pron_counts_nowb.txt $model_dir/sil_counts_nowb.txt \
    $model_dir/pron_bigram_counts_nowb.txt data/local/dict

  utils/prepare_lang.sh data/local/dict \
    "<UNK>" data/local/lang_tmp data/lang

  # Make a new lang dir for each LM
  for lm_suffix in tgmed tglarge; do
    lang_dir_test=data/lang_test_$lm_suffix
    mkdir $lang_dir_test
    cp -r data/lang/* $lang_dir_test
    gunzip -c $lm_dir/${lm_suffix}.arpa.gz | \
        arpa2fst --disambig-symbol=#0 \
          --read-symbol-table=data/lang/words.txt - $lang_dir_test/G.fst
  done

fi

if [ "$compile_graph" -eq "1" ]; then

  printf "\n####===================####\n"
  printf "#### GRAPH COMPILATION ####\n"
  printf "####===================####\n\n"

  prompt_rm_dir $model_dir/graph

  utils/mkgraph.sh \
    data/lang_test_tglarge \
    $model_dir \
    $model_dir/graph || exit 1

fi

if [ "$decode_test" -eq "1" ]; then

  printf "\n####================####\n"
  printf "#### BEGIN DECODING ####\n"
  printf "####================####\n\n"

  prompt_rm_dir $model_dir/decode

  steps/decode_fmllr.sh \
    --config conf/decode.conf \
    --nj $num_procs \
    --cmd $decode_cmd \
    $model_dir/graph \
    $test_acoustic_dir \
    $model_dir/decode

fi

exit