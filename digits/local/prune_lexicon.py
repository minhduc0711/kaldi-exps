import argparse as ap

parser = ap.ArgumentParser()
parser.add_argument("full_lexicon")
parser.add_argument("transcript")
parser.add_argument("pruned_lexicon")

args = parser.parse_args()

# Collect all words in the transcript
present_words = set()
with open(args.transcript) as f:
    for line in f.readlines():
        _, transcript = line.strip().split(" ", 1)
        present_words.update(transcript.split(" "))

# Collect all words & corresponding pronunications from the full lexicons
pronun_dict = {}
with open(args.full_lexicon, encoding="ISO-8859-1") as f:
    for line in f.readlines():
        word, pronun = line.strip().split(" ", 1)
        if word not in pronun_dict:
            pronun_dict[word] = []
        pronun_dict[word].append(pronun)

# Filter out words that don't appear in the transcript
with open(args.pruned_lexicon, "w") as f:
    # add an entry for <UNK>
    f.write("<UNK> SPN\n")
    for word in present_words:
        if word in pronun_dict:
            for pronun in pronun_dict[word]:
                f.write(f"{word}{pronun}\n")
        else:
            print(f"{word} is not in the full lexicon")
