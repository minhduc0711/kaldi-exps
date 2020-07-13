#!/usr/bin/env bash

. local/util_funcs.sh
. ./cmd.sh
. ./path.sh

### STAGES
prep_acoustic=0
extract_feats=0
split_train_data=0
prep_lang_train=0
train_gmm=0
train_lm=0
decode_gmm=0

num_procs=16

train_acoustic_dir=data/train
#
##
###

if [ "$prep_acoustic" -eq "1" ]; then

  printf "\n####==========================####\n"
  printf "####    ACOUSTIC DATA PREP    ####\n"
  printf "####==========================####\n\n"

  # VIVOS
  for raw_dir in raw/vivos/{train,test}; do
    dest_dir=data/vivos_$(basename $raw_dir)
    prompt_rm_dir $dest_dir
    local/prepare_acoustic_vivos.sh $raw_dir $dest_dir || exit 1
  done

  # VAIS1000
  prompt_rm_dir data/vais1000_{train,test}
  ./local/prepare_acoustic_vais1000.sh raw/vais1000/ data/vais1000 || exit 1
  # train/test split
  ./utils/split_data.sh data/vais1000/ 5
  ./utils/combine_data.sh data/vais1000_train/ data/vais1000/split5/{1,2,3,4}
  mv data/vais1000/split5/5/ data/vais1000_test/
  
  # combine two datasets
  ./utils/combine_data.sh data/train data/{vivos,vais1000}_train
  ./utils/combine_data.sh data/test data/{vivos,vais1000}_test 
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

exit 0