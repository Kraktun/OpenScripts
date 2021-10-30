from pathlib import Path
from mutagen.mp4 import MP4

def ask_12_question(question):
    input_file = ""
    while not input_file in ["1", "2"]:
        input_file = input(question)
    return input_file

def get_audio_rate(filename):
    return str(round(MP4(filename).info.bitrate / 1000)) + " kbps"

def main():
    target_folder = input("Enter the target folder:\n")
    target_folder = Path(target_folder)

    files = target_folder.glob("*/*.m4a")
    seen = {}

    for f in files:
        if str(f.stem) in list(seen.keys()):
            print("Found matching files:")
            one = seen[str(f.stem)]
            one_rate = get_audio_rate(target_folder / one)
            two = str(f.relative_to(target_folder))
            two_rate = get_audio_rate(target_folder / two)
            print(f"\t1. [{one_rate}] {one}")
            print(f"\t2. [{two_rate}] {two}")
            res = ask_12_question("Choose the file to KEEP [1\\2]\n")
            if res == "2":
                seen[str(f.stem)] = str(f.relative_to(target_folder))
                (target_folder / one).unlink()
            else:
                (target_folder / two).unlink()
        else:
            seen[str(f.stem)] = str(f.relative_to(target_folder))





if __name__ == "__main__":
    main()