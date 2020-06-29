import argparse as ap
import pandas as pd
import warnings


def create_accent_csv():
    plain = "a ă â e ê i o ô ơ u ư y".split(" ")
    accented = ["á ắ ấ é ế í ó ố ớ ú ứ ý",
                "à ằ ầ è ề ì ò ồ ờ ù ừ ỳ",
                "ả ẳ ẩ ẻ ể ỉ ỏ ổ ở ủ ử ỷ",
                "ã ẵ ẫ ẽ ễ ĩ õ ỗ ỡ ũ ữ ỹ",
                "ạ ặ ậ ẹ ệ ị ọ ộ ợ ụ ự ỵ"]

    accents = ["s", "f", "r", "x", "j"]
    table = []
    for accented_sub, accent in zip(accented, accents):
        for i, symbol in enumerate(accented_sub.split(" ")):
            plain_vowel = plain[i]
            table.append([symbol, plain_vowel, accent])
    pd.DataFrame(table).to_csv("phonetics/vowels.csv",
                               header=["vowel", "stripped_vowel", "accent"],
                               index=False)


def extract_accent(word, accent_dict):
    output_word = ""
    accent = None
    for ch in word:
        if ch in accent_dict:
            stripped_vowel, accent = accent_dict[ch]
            output_word += stripped_vowel
        else:
            output_word += ch
    if not accent:
        accent = ""
    return output_word, accent


def load_grapheme_to_phoneme_dict(path):
    d = {}
    with open(path) as f:
        for row in f.readlines():
            grapheme, phonemes = row.strip().split(" ", 1)
            d[grapheme] = phonemes.split(" ")
    return d


def extract_phonemes(input_word):
    # Grapheme-to-phoneme table are from https://sourceforge.net/projects/vietnamese-grapheme-to-phoneme/
    # Probably the same mapping table is used in "The Effect of Tone Modeling in Vietnamese LVCSR System"
    # Tonal phonemes idea stolen from: "VIETNAMESE RECOGNITION USING TONAL PHONEME BASED ON MULTI SPACE DISTRIBUTION"
    initial_dict = load_grapheme_to_phoneme_dict(
        "phonetics/phone_initial.txt")
    vowel_dict = load_grapheme_to_phoneme_dict("phonetics/phone_vowel.txt")
    coda_dict = load_grapheme_to_phoneme_dict("phonetics/phone_coda.txt")

    current_word, accent = extract_accent(input_word.lower(), accent_dict)
    phonemes = []
    # First check if initial consonant exists
    # The longest initial grapheme has length 3
    for i in range(3, 0, -1):
        if current_word[:i] in initial_dict:
            phonemes.extend(initial_dict[current_word[:i]])
            current_word = current_word[i:]
    # Similar procedure for (nucleus) vowel
    for i in range(3, 0, -1):
        if current_word[:i] in vowel_dict:
            mid_phonemes = [p + accent if p !=
                            "w" else p for p in vowel_dict[current_word[:i]]]
            phonemes.extend(mid_phonemes)
            current_word = current_word[i:]
    # And finally for coda
    for i in range(2, 0, -1):
        if current_word[:i] in coda_dict:
            end_phonemes = [p + accent for p in coda_dict[current_word[:i]]]
            phonemes.extend(end_phonemes)
            current_word = current_word[i:]

    if len(current_word) != 0:
        warnings.warn(f"error extracting phonemes from word {input_word}",
                      UserWarning)
    return [p.upper() for p in phonemes]


# MAIN SCRIPT
parser = ap.ArgumentParser()
parser.add_argument("--text", help="path to the transcript")
parser.add_argument("--dst", help="path to the output (pruned) lexicon")

args = parser.parse_args()
accent_df = pd.read_csv("phonetics/accented_vowels.csv")
accent_dict = {}
for _, row in accent_df.iterrows():
    accent_dict[row[0]] = (row[1], row[2])


# Collect all words in the transcript
present_words = set()
with open(args.text) as f:
    for line in f.readlines():
        _, transcript = line.strip().split(" ", 1)
        present_words.update(transcript.split(" "))
present_words = sorted(list(present_words))

# Build lexicon from text transcripts
lexicon_table = []
for word in present_words:
    lexicon_table.append(word + " " + " ".join(extract_phonemes(word)) + "\n")
with open(args.dst, "w") as f:
    f.write("<UNK> SPN\n")
    for row in lexicon_table:
        f.write(row)
