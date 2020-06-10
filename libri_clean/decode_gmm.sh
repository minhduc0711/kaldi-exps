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
prep_lm=1
prep_test_audio=0
extract_test_feats=0
compile_graph=1
decode_test=1
#
##
###

num_procs=1
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

  local/prepare_lm.sh || exit 1

fi

if [ "$compile_graph" -eq "1" ]; then

  printf "\n####===================####\n"
  printf "#### GRAPH COMPILATION ####\n"
  printf "####===================####\n\n"

  prompt_rm_dir ${model_dir}/graph

  utils/mkgraph.sh \
    ${data_dir}/lang \
    $model_dir \
    ${model_dir}/graph ||
    printf "\n####\n#### ERROR: mkgraph.sh \n####\n\n" || exit 1

fi

if [ "$decode_test" -eq "1" ]; then

  printf "\n####================####\n"
  printf "#### BEGIN DECODING ####\n"
  printf "####================####\n\n"

  prompt_rm_dir ${model_dir}/decode

  steps/decode_fmllr.sh \
    --config ${config_dir}/decode.conf \
    --nj $num_procs \
    --cmd $cmd \
    ${model_dir}/graph \
    $test_acoustic_dir \
    ${model_dir}/decode

fi

exit
