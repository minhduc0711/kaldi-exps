#!/usr/bin/env bash

# Joshua Meyer (2017)

# USAGE:
#
#      ./run.sh <corpus_name>
#
# INPUT:
#
#    input_dir/
#       lexicon.txt
#       lexicon_nosil.txt
#       phones.txt
#       task.arpabo
#       transcripts
#
#       audio_dir/
#          utterance1.wav
#          utterance2.wav
#          utterance3.wav
#               .
#               .
#          utteranceN.wav
#
#    config_dir/
#       mfcc.conf
#       topo_orig.proto
#
#
# OUTPUT:
#
#    exp_dir
#    feat_dir
#    data_dir
#

. local/util_funcs.sh

cmd=utils/run.pl
train_monophones=1
train_triphones=1
adapt_models=1
save_model=0

if [ "$#" -ne 9 ]; then
  echo "ERROR: $0"
  echo "missing args"
  exit 1
fi

data_dir=$1
num_iters_mono=$2
tot_gauss_mono=$3
num_iters_tri=$4
tot_gauss_tri=$5
num_leaves_tri=$6
exp_dir=$7
num_processors=$8
subset_name=$9

# logging purposes
script_start_time=$(date +"%d-%m-%y_%H-%M-%S")
log_dir=logs
if [ ! -d $log_dir ]; then
  mkdir -p $log_dir
fi

if [ "$train_monophones" -eq "1" ]; then
  printf "\n####===========================####\n"
  printf "#### BEGIN TRAINING MONOPHONES ####\n"
  printf "####===========================####\n\n"

  prompt_rm_dir ${exp_dir}/mono ${exp_dir}/mono_ali_5k

  printf "#### Train Monophones ####\n"

  t0="$(date -u +%s.%N)"

  steps/train_mono.sh \
    --cmd "$cmd" \
    --nj $num_processors \
    --boost-silence 1.25 \
    --num-iters $num_iters_mono \
    ${data_dir}/train-2k-shortest \
    ${data_dir}/lang \
    ${exp_dir}/mono || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Training monophones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  ../../../src/gmmbin/gmm-info ${exp_dir}/mono/final.mdl

  printf "#### Align Monophones ####\n"

  t0="$(date -u +%s.%N)"

  steps/align_si.sh \
    --cmd "$cmd" \
    --nj $num_processors \
    --boost-silence 1.25 \
    ${data_dir}/train-5k \
    ${data_dir}/lang \
    ${exp_dir}/mono \
    ${exp_dir}/mono_ali_5k || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Aligning monophones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  printf "\n####===========================####\n"
  printf "#### END TRAINING MONOPHONES ####\n"
  printf "####===========================####\n\n"

fi

if [ "$train_triphones" -eq "1" ]; then

  printf "\n####==========================####\n"
  printf "#### BEGIN TRAINING TRIPHONES ####\n"
  printf "####==========================####\n\n"

  prompt_rm_dir ${exp_dir}/tri_5k ${exp_dir}/tri_ali_10k

  printf "### Train Triphones ###\n"

  t0="$(date -u +%s.%N)"

  # First triphone system on 5k subset
  steps/train_deltas.sh \
    --cmd "$cmd" \
    --boost-silence 1.25 \
    --num-iters $num_iters_tri \
    2000 \
    10000 \
    ${data_dir}/train-5k \
    ${data_dir}/lang \
    ${exp_dir}/mono_ali_5k \
    ${exp_dir}/tri_5k || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Training triphones 5k took: ${elapsed}s" >> logs/runtime_${script_start_time}

  ../../../src/gmmbin/gmm-info ${exp_dir}/tri_5k/final.mdl

  printf "### Align Triphones ###\n"

  t0="$(date -u +%s.%N)"

  steps/align_si.sh \
    --cmd "$cmd" \
    --nj $num_processors \
    ${data_dir}/train-10k \
    ${data_dir}/lang \
    ${exp_dir}/tri_5k \
    ${exp_dir}/tri_ali_10k || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Aligning triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  printf "\n####========================####\n"
  printf "#### END TRAINING TRIPHONES ####\n"
  printf "####========================####\n\n"

fi

if [ "$adapt_models" -eq "1" ]; then

  printf "\n####==========================####\n"
  printf "#### BEGIN SPEAKER ADAPTATION ####\n"
  printf "####==========================####\n\n"

  prompt_rm_dir ${exp_dir}/tri_lda_mllt_10k \
      ${exp_dir}/tri_lda_mllt_ali_10k \
      ${exp_dir}/tri_lda_mllt_sat_10k \
      ${exp_dir}/tri_lda_mllt_sat_ali \
      ${exp_dir}/tri_sat_final

  printf "### Begin LDA + MLLT Triphones ###\n"

  t0="$(date -u +%s.%N)"

  steps/train_lda_mllt.sh \
    --cmd "$cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    --num-iters $num_iters_tri \
    2500 \
    15000 \
    ${data_dir}/train-10k \
    ${data_dir}/lang \
    ${exp_dir}/tri_ali_10k \
    ${exp_dir}/tri_lda_mllt_10k || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Training LDA+MLLT triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  ../../../src/gmmbin/gmm-info ${exp_dir}/tri_lda_mllt_10k/final.mdl

  printf "### Align LDA + MLLT Triphones ###\n"

  t0="$(date -u +%s.%N)"

  steps/align_si.sh \
    --cmd "$cmd" \
    --nj $num_processors \
    --use-graphs true \
    ${data_dir}/train-10k \
    ${data_dir}/lang \
    ${exp_dir}/tri_lda_mllt_10k \
    ${exp_dir}/tri_lda_mllt_ali_10k || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Aligning LDA+MLLT triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  printf "\n####===========================####\n"
  printf "#### BEGIN TRAINING SAT (fMLLR) ####\n"
  printf "####============================####\n\n"

  printf "### Train LDA + MLLT + SAT Triphones ###\n"

  t0="$(date -u +%s.%N)"

  steps/train_sat.sh \
    --cmd "$cmd" \
    --num-iters $num_iters_tri \
    2500 \
    15000 \
    ${data_dir}/train-10k \
    ${data_dir}/lang \
    ${exp_dir}/tri_lda_mllt_ali_10k \
    ${exp_dir}/tri_lda_mllt_sat_10k || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Training LDA+MLLT+SAT triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  ../../../src/gmmbin/gmm-info ${exp_dir}/tri_lda_mllt_sat_10k/final.mdl

  printf "### Align LDA + MLLT + SAT Triphones on the whole train dataset ###\n"

  t0="$(date -u +%s.%N)"

  steps/align_fmllr.sh \
    --cmd "$cmd" \
    --nj $num_processors \
    ${data_dir}/${subset_name} \
    ${data_dir}/lang \
    ${exp_dir}/tri_lda_mllt_sat_10k \
    ${exp_dir}/tri_lda_mllt_sat_ali || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Aligning LDA+MLLT+SAT triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  printf "### Train final SAT Triphones on all utterances ###\n"

  t0="$(date -u +%s.%N)"

  steps/train_sat.sh \
    --cmd "$cmd" \
    --num-iters $num_iters_tri \
    4200 \
    40000 \
    ${data_dir}/${subset_name} \
    ${data_dir}/lang \
    ${exp_dir}/tri_lda_mllt_sat_ali \
    ${exp_dir}/tri_sat_final || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Training final SAT triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  ../../../src/gmmbin/gmm-info ${exp_dir}/tri_sat_final/final.mdl
fi

if [ "$save_model" -eq "1" ]; then
  # Copy all necessary files to use new LM with this acoustic model
  # and only necessary files to save space

  cp $data_dir ${corpus_name}_${run}

  # delete unneeded files
  rm -rf ${corpus_name}_${run}/train ${corpus_name}_${run}/test ${corpus_name}_${run}/lang_decode

  # copy acoustic model and decision tree to new dir
  mkdir ${corpus_name}_${run}/model
  cp exp_${corpus_name}/triphones/final.mdl ${corpus_name}_${run}/model/final.mdl
  cp exp_${corpus_name}/triphones/tree ${corpus_name}_${run}/model/tree

  tar -zcvf ${corpus_name}_${run}.tar.gz ${corpus_name}_${run}

  # clean up
  rm -rf ${corpus_name}_${run}

  # move for storage
  mkdir compressed_experiments

  mv ${corpus_name}_${run}.tar.gz compressed_experiments/${corpus_name}_${run}.tar.gz
fi

exit
