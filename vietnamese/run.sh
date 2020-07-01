#!/usr/bin/env bash

. local/util_funcs.sh
. ./cmd.sh
. ./path.sh

### STAGES
prep_acoustic=1
extract_feats=1
split_train_data=1
prep_lang_train=1
train_gmm=1
train_lm=1
decode_gmm=1

num_procs=16

train_acoustic_dir=data/train
#
##
###

if [ "$prep_acoustic" -eq "1" ]; then

  printf "\n####==========================####\n"
  printf "####    ACOUSTIC DATA PREP    ####\n"
  printf "####==========================####\n\n"

  for raw_dir in raw/vivos/{train,test}; do
    prompt_rm_dir $raw_dir
    local/prepare_acoustic.sh $raw_dir || exit 1
  done
fi

if [ "$extract_feats" -eq "1" ]; then

  printf "\n####==========================####\n"
  printf "####    FEATURE EXTRACTION    ####\n"
  printf "####==========================####\n\n"
  prompt_rm_dir mfcc
  for subset in train test; do
    steps/make_mfcc.sh --nj $num_procs data/$subset exp/make_mfcc/$subset mfcc
    steps/compute_cmvn_stats.sh data/$subset exp/make_mfcc/$subset mfcc
  done
fi

if [ $split_train_data -eq 1 ]; then
  # Make small data subsets for easier alignment during early training stages
  # the full train dataset has 11.6k utterances

  printf "\n####==========================####\n"
  printf "#### SUBSETTING TRAIN DATA    ####\n"
  printf "####==========================####\n\n"
  prompt_rm_dir data/{train_small_shortest,train_med,train_large}

  utils/subset_data_dir.sh --shortest $train_acoustic_dir 800 data/train_small_shortest
  utils/subset_data_dir.sh $train_acoustic_dir 2000 data/train_med
  utils/subset_data_dir.sh $train_acoustic_dir 4000 data/train_large
fi

if [ "$prep_lang_train" -eq "1" ]; then

  printf "\n####====================================####\n"
  printf "#### CREATING LANG NOSP DIR FOR TRAINING ####\n"
  printf "####=====================================####\n\n"

  prompt_rm_dir data/local data/lang_nosp

  local/prepare_dict.sh $train_acoustic_dir data/local/dict_nosp || exit 1
  utils/prepare_lang.sh data/local/dict_nosp \
    "<UNK>" data/local/lang_tmp_nosp data/lang_nosp || exit 1
   
fi

if [ "$train_gmm" -eq "1" ]; then

  printf "\n####===============####\n"
  printf "#### TRAINING GMMs ####\n"
  printf "####===============####\n\n"

  ./train_gmm.sh $num_procs
fi

if [ $train_lm -eq 1 ]; then
  printf "\n####===============####\n"
  printf "#### TRAINING LMs  ####\n"
  printf "####===============####\n\n"

  lm_dir=lm
  prompt_rm_dir lm

  mkdir -p lm
  # Prepare text corpus
  ./local/clean_text.py --inputs raw/text_data_vn/{vivos_train,VNESEcorpus}.txt \
      --output lm/clean_corpus.txt
  # Train n-gram models
  ./local/train_lm.sh lm/clean_corpus.txt lm
fi

if [ $decode_gmm -eq 1 ]; then
  ./local/decode_gmm.sh exp/tri_sat_final/ data/test $num_procs
fi

exit
