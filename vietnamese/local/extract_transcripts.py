#!/root/miniconda3/envs/asr/bin/python

import argparse as ap

parser = ap.ArgumentParser()
parser.add_argument("input_path", type=str)
parser.add_argument("output_path", type=str)

args = parser.parse_args()

with open(args.input_path, 'r') as f_in, open(args.output_path, 'w') as f_out:
    for line in f_in.readlines():
        _, sentence = line.split(" ", 1)
        f_out.write(sentence)
