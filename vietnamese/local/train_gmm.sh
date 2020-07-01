#!/usr/bin/env bash

. local/util_funcs.sh
. ./cmd.sh


if [ "$#" -ne 1 ]; then
  echo "USAGE: $0 <num_procs>"
  exit 1
fi

num_processors=$1

# STAGES
train_monophones=1
train_triphones=1
adapt_models=1
save_model=0

# HYPERPARAMS
num_iters_mono=40
tot_gauss_mono=1000

num_iters_tri=35
tot_gauss_tri=2000
num_leaves_tri=10000

num_iters_lda_mllt=35
tot_gauss_lda_mllt=2500
num_leaves_lda_mllt=15000

num_iters_sat=35
tot_gauss_sat=2500
num_leaves_sat=15000

num_iters_sat_final=35
tot_gauss_sat_final=4200
num_leaves_sat_final=40000

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

  prompt_rm_dir exp/mono_small exp/align_mono_med

  printf "#### Train Monophones ####\n"

  t0="$(date -u +%s.%N)"

  steps/train_mono.sh \
    --cmd "$train_cmd" \
    --nj $num_processors \
    --boost-silence 1.25 \
    --num-iters $num_iters_mono \
    --totgauss $tot_gauss_mono
    data/train_small_shortest \
    data/lang_nosp \
    exp/mono_small || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Training monophones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  ../../../src/gmmbin/gmm-info exp/mono_small/final.mdl

  printf "#### Align Monophones ####\n"

  t0="$(date -u +%s.%N)"

  steps/align_si.sh \
    --cmd "$train_cmd" \
    --nj $num_processors \
    --boost-silence 1.25 \
    data/train_med \
    data/lang_nosp \
    exp/mono_small \
    exp/align_mono_med || exit 1

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

  prompt_rm_dir exp/tri_med exp/align_tri_large

  printf "### Train Triphones ###\n"

  t0="$(date -u +%s.%N)"

  # First triphone system on 5k subset
  steps/train_deltas.sh \
    --cmd "$train_cmd" \
    --boost-silence 1.25 \
    --num-iters $num_iters_tri \
    $tot_gauss_tri \
    $num_leaves_tri \
    data/train_med \
    data/lang_nosp \
    exp/align_mono_med \
    exp/tri_med || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Training triphones 5k took: ${elapsed}s" >> logs/runtime_${script_start_time}

  ../../../src/gmmbin/gmm-info exp/tri_med/final.mdl

  printf "### Align Triphones ###\n"

  t0="$(date -u +%s.%N)"

  steps/align_si.sh \
    --cmd "$train_cmd" \
    --nj $num_processors \
    data/train_large \
    data/lang_nosp \
    exp/tri_med \
    exp/align_tri_large || exit 1

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

  prompt_rm_dir exp/tri_lda_mllt_large \
      exp/align_tri_lda_mllt_large \
      exp/tri_sat_large \
      exp/align_tri_sat_large \
      exp/tri_sat_final

  printf "### Begin LDA + MLLT Triphones ###\n"

  t0="$(date -u +%s.%N)"

  steps/train_lda_mllt.sh \
    --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    --num-iters $num_iters_lda_mllt \
    $tot_gauss_lda_mllt \
    $num_leaves_lda_mllt \
    data/train_large \
    data/lang_nosp \
    exp/align_tri_large \
    exp/tri_lda_mllt_large || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Training LDA+MLLT triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  ../../../src/gmmbin/gmm-info exp/tri_lda_mllt_large/final.mdl

  printf "### Align LDA + MLLT Triphones ###\n"

  t0="$(date -u +%s.%N)"

  steps/align_si.sh \
    --cmd "$train_cmd" \
    --nj $num_processors \
    --use-graphs true \
    data/train_large \
    data/lang_nosp \
    exp/tri_lda_mllt_large \
    exp/align_tri_lda_mllt_large || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Aligning LDA+MLLT triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  printf "\n####===========================####\n"
  printf "#### BEGIN TRAINING SAT (fMLLR) ####\n"
  printf "####============================####\n\n"

  printf "### Train LDA + MLLT + SAT Triphones ###\n"

  t0="$(date -u +%s.%N)"

  steps/train_sat.sh \
    --cmd "$train_cmd" \
    --num-iters $num_iters_sat \
    $tot_gauss_sat \
    $num_leaves_sat \
    data/train_large \
    data/lang_nosp \
    exp/align_tri_lda_mllt_large \
    exp/tri_sat_large || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Training LDA+MLLT+SAT triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  ../../../src/gmmbin/gmm-info exp/tri_sat_large/final.mdl

  printf "### Align LDA + MLLT + SAT Triphones on the whole train dataset ###\n"

  t0="$(date -u +%s.%N)"

  steps/align_fmllr.sh \
    --cmd "$train_cmd" \
    --nj $num_processors \
    data/train \
    data/lang_nosp \
    exp/tri_sat_large \
    exp/align_tri_sat_large || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Aligning LDA+MLLT+SAT triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  printf "### Train final SAT Triphones on all utterances ###\n"

  t0="$(date -u +%s.%N)"

  steps/train_sat.sh \
    --cmd "$train_cmd" \
    --num-iters $num_iters_sat_final \
    $tot_gauss_sat_final \
    $num_leaves_sat_final \
    data/train \
    data/lang_nosp \
    exp/align_tri_sat_large \
    exp/tri_sat_final || exit 1

  t1="$(date -u +%s.%N)"
  elapsed="$(bc <<<"$t1-$t0")"
  echo "Training final SAT triphones took: ${elapsed}s" >> logs/runtime_${script_start_time}

  ../../../src/gmmbin/gmm-info exp/tri_sat_final/final.mdl
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
