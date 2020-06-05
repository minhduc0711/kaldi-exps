import argparse as ap

parser = ap.ArgumentParser()
parser.add_argument("--src", help="path to the original lexicon")
parser.add_argument("--dst", help="path to the output (pruned) lexicon")
parser.add_argument("--trans", help="path to the transcript")

args = parser.parse_args()

# Collect all words in the transcript
present_words = set()
with open(args.trans) as f:
    for line in f.readlines():
        _, transcript = line.strip().split(" ", 1)
        present_words.update(transcript.split(" "))

# Collect all words & corresponding pronunications from the full lexicons
pronun_dict = {}
with open(args.src, encoding="ISO-8859-1") as f:
    for line in f.readlines():
        row = line.strip().replace("\t", " ")
        word, pronun = row.split(" ", 1)
        if word not in pronun_dict:
            pronun_dict[word] = set()
        pronun_dict[word].add(pronun.strip())

# Filter out words that don't appear in the transcript
unknown_words = []
with open(args.dst, "w") as f:
    # add an entry for <UNK>
    f.write("<UNK> SPN\n")
    for word in present_words:
        if word in pronun_dict:
            for pronun in pronun_dict[word]:
                f.write("{} {}\n".format(word, pronun))
        else:
            unknown_words.append(word)
print("{} words are not in the lexicon: {}".format(len(unknown_words), unknown_words)
