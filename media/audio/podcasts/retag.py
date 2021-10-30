from mutagen.mp4 import MP4
import emoji
from pathlib import Path
import re
import os
import itertools
import json

def get_field(filename, field):
    return MP4(filename).tags.get(field, [None])[-1]

def set_field(filename, field, value):
    tags = MP4(filename).tags
    tags[field] = value
    tags.save(filename)

def de_emojify(text):
    return emoji.get_emoji_regexp().sub(r'', text)

def clean_text(text):
    text = re.sub(r'\[.*\]', '', text)
    text = re.sub(r'\(.*\)', '', text)
    text = text.replace("  ", " ")
    remove_chars = ["-", "_", "–", ".", ",", ";", "'", ":", " "]
    while len(text) > 0 and (text[0] in remove_chars or text[-1] in remove_chars):
        for c in remove_chars:
            text = text.strip(c)
    return text.strip()

def remove_all_permutations(chunks, full_string):
    chunks = [de_emojify(s) for s in chunks]
    chunks = [clean_text(s) for s in chunks]
    perms = list(itertools.permutations(chunks))
    for perm in perms:
        all_lower = " ".join(perm)
        # note: do not use strip(), it matches also partial strings
        full_string = re.sub(f'{all_lower}$', '', full_string) # remove at the end
        full_string = re.sub(f'^{all_lower}', '', full_string) # remove at the beginning
            

        first_upper = [s[0].upper() + s[1:] if len(s) > 1 else s.upper() for s in perm]
        # there are more permutations than necessary, but names and albums are usually made up of a few (<10) words so it should be fine
        for i in range(len(perm)):
            perm_t = list(perm).copy()
            perm_t[i] = first_upper[i]
            my_string = " ".join(perm_t)
            full_string = re.sub(f'{my_string}$', '', full_string) # remove at the end
            full_string = re.sub(f'^{my_string}', '', full_string) # remove at the beginning
            for j in range(len(perm)):
                perm_t[j] = first_upper[j]
                my_string = " ".join(perm_t)
                full_string = re.sub(f'{my_string}$', '', full_string)
                full_string = re.sub(f'^{my_string}', '', full_string)
    return full_string

def author_album_clean(author, album, filename):
    new_filename = de_emojify(filename)
    new_filename = clean_text(new_filename)
    author_chunks = author.lower().split(" ")
    new_filename = remove_all_permutations(author_chunks, new_filename)
    album_chunks = album.lower().split(" ")
    new_filename = remove_all_permutations(album_chunks, new_filename)
    new_filename = de_emojify(new_filename)
    new_filename = clean_text(new_filename)
    return new_filename

def ask_yn_question(question):
    input_file = ""
    while not input_file in ["n", "N", "y", "Y"]:
        input_file = input(question)
    input_file = (input_file in ["y", "Y"]) # transform to bool
    return input_file

def main():
    # folders must be organized in this form:
    # TARGET_FOLDER / AUTHOR_NAME / ALBUM_NAME / *.m4a,*.mp3
    
    # ask for the folder
    target_folder = input("Enter the target folder:\n")
    sanitize_names = ask_yn_question("Do you want to sanitize the filenames and titles (remove emoji etc)? [y/n] ")
    output_file = Path(target_folder) / "output_retag.json"
    output_list = []
    
    authors = Path(target_folder).glob("*")
    for author_folder in authors:
        author_name = author_folder.stem
        print(f"Parsing author: {author_name}")
        for album_folder in author_folder.glob("*"):
            album_name = album_folder.stem
            print(f"\tParsing album: {album_name}")
            for filename in album_folder.glob("*.m4a"):
                title = filename.stem # some edits should be done here
                print(f"\t\tParsing file: {title}")
                if sanitize_names:
                    title = de_emojify(title)
                    title = clean_text(title)
                    title = author_album_clean(author_name, album_name, title)
                    if len(title) == 0:
                        title = album_name
                
                set_field(filename.resolve(), "\xa9nam", title) # title
                set_field(filename.resolve(), "\xa9alb", album_name) # album
                set_field(filename.resolve(), "\xa9ART", author_name) # artist
                print(f"\t\t\tOutput is: TITLE: {title}, AUTHOR: {author_name}, ALBUM: {album_name}")
                new_filename = title
                counter = 1
                # avoid conflicts
                if not new_filename == filename.stem:
                    while (filename.parent / (new_filename + filename.suffix)).exists():
                        new_filename = new_filename + f"_{counter}"
                        counter +=1
                    filename.rename(filename.parent / (new_filename + filename.suffix))

                output_list.append({
                    "file_path" : str(filename.relative_to(Path(target_folder))),
                    "new_filename" : new_filename,
                    "author" : author_name,
                    "album" : album_name,
                    "title" : title
                })
    
    with open(output_file, 'a', encoding='utf-8') as f:
        json.dump(output_list, f, ensure_ascii=False, indent=4)

if __name__ == "__main__":
    main()