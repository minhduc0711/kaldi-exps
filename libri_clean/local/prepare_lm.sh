#1/usr/bin/env bash

if [ "$#" -ne 1 ]; then
    echo "ERROR: $0"
    echo "USAGE: $0 <lang_dir>"
    exit 1
fi

lang_dir=$1

. ./path.sh

# Download pretrained n-grams
lm_url=http://www.openslr.org/resources/11/3-gram.pruned.3e-7.arpa.gz
lm_name=`basename ${lm_url}`
if [ ! -f external/`basename $lm_name .gz` ]; then
    wget $lm_url -P external
    gunzip external/$lm_name
fi

arpa2fst --disambig-symbol=#0 --read-symbol-table=${lang_dir}/words.txt external/`basename ${lm_url} .gz` ${lang_dir}/G.fst
