#!/root/miniconda3/envs/asr/bin/python

import argparse as ap
import re

parser = ap.ArgumentParser()
parser.add_argument("transcript", type=str)
parser.add_argument("output_path", type=str)
args = parser.parse_args()

with open(args.transcript, 'r') as f_in, open(args.output_path, 'w') as f_out:
    for line in f_in.readlines():
        fixed_line = re.sub(r"[|,]", " ", line)
        fixed_line = " ".join(fixed_line.split())
        fixed_line = fixed_line.upper()
        f_out.write(fixed_line + "\n")
