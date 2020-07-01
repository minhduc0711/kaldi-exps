#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
  echo "USAGE: $0 <model_dir>"
  exit 1
fi

model_dir=$1

. ./cmd.sh
. ./path.sh
. local/util_funcs.sh

### STAGES
##
#
prep_lm=1
prep_test_audio=1
extract_test_feats=1
compile_graph=1
decode_test=1
#
##
###

num_procs=16
config_dir=conf

# Dirs
data_dir=data
exp_dir=exp
mfcc_dir=mfcc
lm_dir=lm

raw_test_dir=raw/vivos/test
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

  lang_dir_final=data/lang
  # decode using the trained model with pronunciation and silence probabilities
  steps/get_prons.sh --cmd "$decode_cmd" \
        data/train ${data_dir}/lang_nosp $model_dir
  utils/dict_dir_add_pronprobs.sh --max-normalize true \
                                  data/local/dict_nosp \
                                  ${model_dir}/pron_counts_nowb.txt ${model_dir}/sil_counts_nowb.txt \
                                  ${model_dir}/pron_bigram_counts_nowb.txt data/local/dict
  utils/prepare_lang.sh data/local/dict \
                        "<UNK>" data/local/lang_tmp $lang_dir_final

  # Make a new lang dir for each LM
  for lm_suffix in tgmed tglarge; do
    lang_dir_test=${lang_dir_final}_test_$lm_suffix
    mkdir $lang_dir_test
    cp -r $lang_dir_final/* $lang_dir_test
    gunzip -c $lm_dir/${lm_suffix}.arpa.gz | \
        arpa2fst --disambig-symbol=#0 \
          --read-symbol-table=data/lang/words.txt - $lang_dir_test/G.fst
  done

fi

if [ "$compile_graph" -eq "1" ]; then

  printf "\n####===================####\n"
  printf "#### GRAPH COMPILATION ####\n"
  printf "####===================####\n\n"

  prompt_rm_dir ${model_dir}/graph

  utils/mkgraph.sh \
    ${data_dir}/lang_test_tglarge \
    $model_dir \
    ${model_dir}/graph || exit 1

fi

if [ "$decode_test" -eq "1" ]; then

  printf "\n####================####\n"
  printf "#### BEGIN DECODING ####\n"
  printf "####================####\n\n"

  prompt_rm_dir $model_dir/decode

  steps/decode_fmllr.sh \
    --config ${config_dir}/decode.conf \
    --nj $num_procs \
    --cmd $decode_cmd \
    ${model_dir}/graph \
    $test_acoustic_dir \
    ${model_dir}/decode

fi

exit
