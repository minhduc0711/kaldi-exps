#!/usr/bin/env bash

decode_dir=$1

grep WER ${decode_dir}/wer* | utils/best_wer.sh
