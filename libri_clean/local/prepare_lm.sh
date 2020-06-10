#1/usr/bin/env bash

. ./path.sh

# Download pretrained n-grams
lm_url=http://www.openslr.org/resources/11/3-gram.pruned.3e-7.arpa.gz
lm_name=`basename ${lm_url}`
if [ ! -f external/`basename $lm_name .gz` ]; then
    wget $lm_url -P external
    gunzip external/$lm_name
fi

lang=data/lang
arpa2fst --disambig-symbol=#0 --read-symbol-table=$lang/words.txt external/`basename ${lm_url} .gz` $lang/G.fst