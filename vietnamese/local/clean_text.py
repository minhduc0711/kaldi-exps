#!/root/miniconda3/envs/asr/bin/python

import re
import string
import argparse as ap

from tqdm import tqdm


def remove_ellipsis(s):
    # Fix ellipsis that separate sentences
    pattern_1 = r"[.]{2,}(?= *([A-Z]|\n))"
    res = re.sub(pattern_1, ".", s)

    # Fix ellipsis that are in the middle of the sentence
    pattern_2 = r"[.]{2,}(?= *([a-z]))"
    res = re.sub(pattern_2, " ", res)
    return res


def get_clean_sentences(line):
    res = []

    # Take care of ellipsis first
    line = remove_ellipsis(line)

    # There could be many sentences in 1 line
    for sentence in re.split('[.:;!?]', line):
        clean_sentence = sentence.strip()

        # Replace punctuation with spaces
        clean_sentence = clean_sentence.translate(
            str.maketrans(punctuation, ' ' * len(punctuation)))

        # TODO: maybe replace numbers with written forms of numbers?
        # Replace numbers with spaces
        clean_sentence = clean_sentence.translate(
            str.maketrans(string.digits, ' ' * len(string.digits)))

        # Remove redundant spaces
        clean_sentence = ' '.join(clean_sentence.split())

        # Convert to uppercase
        clean_sentence = clean_sentence.upper()

        if len(clean_sentence) != 0:
            res.append(clean_sentence)

    return res


parser = ap.ArgumentParser()
parser.add_argument("--inputs", nargs="+",
                    type=str, required=True)
parser.add_argument("--output", type=str, required=True)
args = parser.parse_args()

punctuation = string.punctuation + "“”‘’…–"

with open(args.output, 'w') as f_out:
    for input_path in args.inputs:
        with open(input_path, 'r') as f_in:
            for line in tqdm(f_in.readlines(),
                             desc=f"Processing {input_path}"):
                for clean_sentence in get_clean_sentences(line):
                    f_out.write(f"{clean_sentence}\n")
