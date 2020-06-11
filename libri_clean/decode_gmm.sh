#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
  echo "USAGE: $0 <raw_test_dir> <model_dir>"
  exit 1
fi

raw_test_dir=$1
model_dir=$2

. local/util_funcs.sh

### STAGES
##
#
prep_lm=0
prep_test_audio=0
extract_test_feats=0
compile_graph=0
decode_test=1
#
##
###

num_procs=16
config_dir=conf
cmd="utils/run.pl"

# Dirs
data_dir=data
exp_dir=exp
mfcc_dir=mfcc

test_subset_name=$(basename $raw_test_dir)
test_acoustic_dir=${data_dir}/$test_subset_name

if [ "$prep_test_audio" -eq "1" ]; then

  printf "\n####==========================####\n"
  printf "#### TESTING AUDIO DATA PREP ####\n"
  printf "####==========================####\n\n"

  prompt_rm_dir $test_acoustic_dir
  local/prepare_acoustic.sh $raw_test_dir || exit 1

fi

if [ "$extract_test_feats" -eq "1" ]; then

  printf "\n####=========================####\n"
  printf "#### TEST FEATURE EXTRACTION ####\n"
  printf "####=========================####\n\n"

  prompt_rm_dir ${exp_dir}/make_mfcc/${test_subset_name} $mfcc_dir

  steps/make_mfcc.sh --nj $num_procs $test_acoustic_dir exp/make_mfcc/$test_subset_name $mfcc_dir
  steps/compute_cmvn_stats.sh $test_acoustic_dir exp/make_mfcc/$test_subset_name $mfcc_dir

fi

if [ "$prep_lm" -eq "1" ]; then

  printf "\n####==============####\n"
  printf "#### PREPARING LM ####\n"
  printf "####==============####\n\n"

  local/prepare_lm.sh data/lang || exit 1

fi

if [ "$compile_graph" -eq "1" ]; then

  printf "\n####===================####\n"
  printf "#### GRAPH COMPILATION ####\n"
  printf "####===================####\n\n"

  prompt_rm_dir ${model_dir}/graph

  utils/mkgraph.sh \
    ${data_dir}/lang \
    $model_dir \
    ${model_dir}/graph || exit 1

fi

if [ "$decode_test" -eq "1" ]; then

  printf "\n####================####\n"
  printf "#### BEGIN DECODING ####\n"
  printf "####================####\n\n"

#  prompt_rm_dir ${model_dir}/decode

  # decode using the tri SAT model with pronunciation and silence probabilities
  steps/get_prons.sh --cmd "$cmd" \
        data/train-clean-100 ${data_dir}/lang $model_dir
  utils/dict_dir_add_pronprobs.sh --max-normalize true \
                                  data/local/dict \
                                  ${model_dir}/pron_counts_nowb.txt ${model_dir}/sil_counts_nowb.txt \
                                  ${model_dir}/pron_bigram_counts_nowb.txt data/local/dict_sp
  utils/prepare_lang.sh data/local/dict_sp \
                        "<UNK>" data/local/lang_tmp_sp data/lang_sp
  local/prepare_lm.sh ${data_dir}/lang_sp

  utils/mkgraph.sh \
    ${data_dir}/lang_sp \
    $model_dir \
    ${model_dir}/graph_sp || exit 1

  steps/decode_fmllr.sh \
    --config ${config_dir}/decode.conf \
    --nj $num_procs \
    --cmd $cmd \
    ${model_dir}/graph_sp \
    $test_acoustic_dir \
    ${model_dir}/decode_sp

fi

exit
