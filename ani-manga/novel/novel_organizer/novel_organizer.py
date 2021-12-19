from pathlib import Path
import os
import shutil
import re
import requests
import sys

# name of the main output folder
OUTPUT_FOLDER = "OFFICIAL"
# subfolder of the main output folder where to store complete series
OUTPUT_COMPLETE = "COMPLETE"
# subfolder of the main output folder where to store ongoing series
OUTPUT_ONGOING = "ONGOING"
# folders to exclude during the search (they are excluded at all levels, so paths are not supported)
SKIP_FOLDERS = ["!Completed", "!EPUB", "!PDF"]

def main(target_folder, mode, filters_file):
    """
    Main method: scan the input folder, filter the files according to the filters included
        target_folder: string with the folder cotaining all the folders of the novels (structure must be target_folder/Novel_A/Volume_1.pdf)
        mode: 'c' or 'm' for copy or move, symlinks will be added later
        filters_file: file with a list of tags in order of importance, such that if two files have the same name but different tags, the one 
            with the highest level tag (i.e. the one that appear earlier in filters_file) will be kept. If it is None, all files will be copied/moved.
            Note that tags are defined as strings between square brackets or extensions, for example in "This is a common file [tag1][tag2].pdf" the 
            tags are tag1, tag2 and .pdf (the point is included).
    """
    # get the list of completed series
    completed_series = get_complete_list(target_folder)
    # output folder will be on the parent of the folder where all novels are
    parent_folder = str(Path(target_folder).parent)
    output_complete_folder = os.path.join(parent_folder, OUTPUT_FOLDER, OUTPUT_COMPLETE)
    output_ongoing_folder = os.path.join(parent_folder, OUTPUT_FOLDER, OUTPUT_ONGOING)
    Path(output_complete_folder).mkdir(parents=True, exist_ok=True)
    Path(output_ongoing_folder).mkdir(parents=True, exist_ok=True)
    # walk through all subfolders and skip the main one (target_folder itself)
    subfolders = [x[0] for x in os.walk(target_folder)][1:]
    # remove excluded folders
    subfolders = [s for s in subfolders if not os.path.basename(s) in SKIP_FOLDERS]
    counter = 1
    # get list of tags in order of importance
    filters = get_all_filters(filters_file)

    print("\n\tPROCESSING...\n")
    for s in subfolders:
        # full path
        full_s = s
        # relative path
        s = os.path.relpath(full_s, target_folder)
        print_statusline(f"[{counter}/{len(subfolders)}] : {s}")
        counter = counter+1
        
        # compare equal files (i.e. same book) and get the best according to their tags
        best_matches = get_best_files(full_s, filters)
        # choose output folder according to the list of completed series
        # note: use first part of relative path (i.e. main folder of the serie) or all the subfolders (e.g. side stories) will fail the comparison
        main_s = s.split(os.path.sep)[0]
        if main_s in completed_series:
            out_folder = os.path.join(output_complete_folder, s)
        else:
            out_folder = os.path.join(output_ongoing_folder, s)
        Path(out_folder).mkdir(parents=True, exist_ok=True)
        
        if mode == "c":
            for b in best_matches:
                # build output path
                full_b = os.path.join(full_s, b)
                # copy file if not already present
                if not os.path.isfile(os.path.join(out_folder, b)):
                    shutil.copy2(full_b, os.path.join(out_folder, b))
        else:
            for b in best_matches:
                full_b = os.path.join(full_s, b)
                if not os.path.isfile(os.path.join(out_folder, b)):
                    shutil.move(full_b, os.path.join(out_folder, b))

def get_complete_list(target_folder):
    """
    Get the list of completed series from the pastebin link in the bat file included in current releases of a known novel pack.
    Save the list to completed_series.txt and reuse it if already present.
    """
    output_file = os.path.join(target_folder, "completed_series.txt")
    if Path(output_file).exists():
        with open(output_file, 'r') as f:
            completed_series = f.read().splitlines()
    else:
        bat_file = os.path.join(target_folder, "!Completed", "GenerateCompletedLinksScriptAll.bat")
        with open(bat_file) as fb:
            bat_data = fb.read()
        res = re.findall(r"https:\/\/pastebin.com\/raw\/(.*)\)", bat_data)[0]
        url = f"https://pastebin.com/raw/{res}"
        r = requests.get(url)
        # remove redundant \r
        completed_series = r.text.replace("\r\n", "\n")
        with open(output_file, 'w') as f:
            f.write(completed_series)
        completed_series = completed_series.splitlines()
    return completed_series

def get_tags(s):
    # get tags in a filename using regex. 
    # Includes all strings between square brackets and file extension.
    all_tags = [Path(s).suffix]
    all_tags.extend(re.findall(r'\[(.*?)]', s))
    return all_tags

def export_all_tags(target_folder, export_file):
    # save a list with all the tags included in all files, to help in the creation of the filters_file
    subfolders = [x[0] for x in os.walk(target_folder)][1:]
    subfolders = [s for s in subfolders if not os.path.basename(s) in SKIP_FOLDERS]
    tags = set()
    for s in subfolders:
        files = [f for f in os.listdir(s) if os.path.isfile(os.path.join(s, f))]
        for f in files:
            for t in get_tags(f):
                tags.add(t)
    tags = sorted(tags)
    with open(export_file, 'w') as f:
        f.write('\n'.join(tags))

def get_best_files(folder, filters):
    """
    Compare all files in a folder that differ only by tags (and extension) and return only the best one according to their tags.
    If filters is None, return all files.
        folder: folder containing the files to check
        filters: list of filters in order of importance
    """
    # list all the files
    files = [f for f in os.listdir(folder) if os.path.isfile(os.path.join(folder, f))]
    files = [Path(f) for f in files]
    files = sorted(files)
    paired_names = [] # contains tuples in the form: (simple_name, [(file_name, [tag1, tag2, ..., tagN])])
    for f in files:
        # get the simple filename, i.e. without extension and tags
        simple_name = re.findall(r"([^\[]*)", f.name)[0]
        # check if there is an entry with the same name
        found = False
        for tp in paired_names:
            if tp[0] == simple_name:
                # if yes, add to the list of files with the same simple name (i.e. the same book)
                tp[1].append((f, get_tags(f.name)))
                found = True
                break
        if not found:
            # no other file has the same name, add as a new entry
            current_tuple = (simple_name, [(f, get_tags(f.name))])
            paired_names.append(current_tuple)
    # loop paired_names, check for each simple name, which full name has the highest tag (if equal check second etc.) 
    # and get the best for each simple name, return all such full names
    best_matches = []
    for pn in paired_names:
        _, common_files = pn
        if filters is not None:
            # set first entry as the best one
            current_best = common_files[0][0]
            current_tags = common_files[0][1]
            # loop through all the others
            for file, tags in common_files[1:]:
                if has_better_tags(current_tags, tags, filters):
                    current_best = file
                    current_tags = tags
            best_matches.append(current_best)
        else:
            # add all
            for file, _ in common_files:
                best_matches.append(file)
    return best_matches

def has_better_tags(source_tags, new_tags, filters):
    # true if new_tags are better than source_tags
    for f in filters:
        if f in source_tags and f not in new_tags:
            return False # source has one better tag
        elif f not in source_tags and f in new_tags:
            return True # new has one better tag
        # else continue if both have the same tag or none has it
    return False # files are equal (either they have the same tags or their different tags are not included in the filters), keep the source
    
def get_all_filters(filters_file):
    # get list with all tags ordered by importance
    if filters_file is None:
        return None
    with open(filters_file, "r") as f:
        filters = f.read().splitlines()
    # remove empty lines
    filters = [s.strip() for s in filters]
    filters = [s for s in filters if len(s) > 0]
    # remove comments
    filters = [s for s in filters if not s.startswith("#")]
    return filters

def ask_copy_move():
    res = input("Do you want to copy or move the files? [c/m] ")
    if res.lower() in ["c", "m"]:
        return res
    else:
        print("Invalid choice\n")
        return ask_copy_move()

def ask_yes_no(string):
    res = input(string)
    if res.lower() == "y":
        return True
    elif res.lower() == "n":
        return False
    else:
        print("Invalid choice\n")
        return ask_yes_no(string)

def print_statusline(msg: str):
    # https://stackoverflow.com/a/43952192
    last_msg_length = len(print_statusline.last_msg) if hasattr(print_statusline, 'last_msg') else 0
    print(' ' * last_msg_length, end='\r')
    print(msg, end='\r')
    sys.stdout.flush()
    print_statusline.last_msg = msg

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    target_folder = input("Enter the path to the folder containing the novels (usually 'path/to/Off...T...L...N...')\n")
    mode = ask_copy_move()
    filter = ask_yes_no("Do you want to copy/move only one file per book? [y/n] ")
    if filter:
        filter_file = input("Enter the path to the filter txt file:\n")
    else:
        filter_file = None
    main(target_folder, mode, filter_file)
    # export_file = input("Enter the name of the output export file\n")
    # export_all_tags(target_folder, export_file)
