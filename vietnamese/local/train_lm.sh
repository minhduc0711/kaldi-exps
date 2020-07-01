#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
  echo "USAGE: $0 <txt_dataset_file> <output_dir>"
  exit 1
fi

. ./path.sh

text_file=$1
output_dir=$2

prune_thresh_small=0.0000003
prune_thresh_medium=0.0000001

echo "Training 3-gram"

tglarge_path=$output_dir/tglarge.arpa.gz
ngram-count -order 3 \
  -kndiscount -interpolate \
  -unk -map-unk "<UNK>" \
  -write-vocab $output_dir/vocab-full.txt \
  -text $text_file -lm $tglarge_path || exit 1
du -h $tglarge_path

echo "Creating pruned 3-gram medium"
tgmed_path=$output_dir/tgmed.arpa.gz
ngram -prune $prune_thresh_medium -lm $tglarge_path -write-lm $tgmed_path || exit 1
du -h $tgmed_path