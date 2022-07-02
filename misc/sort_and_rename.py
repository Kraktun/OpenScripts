import re
import os
import argparse

"""
Given an input regex, sort the files with the given regex and rename them in ascending order.
"""

INPUT_REGEX = r"(PXL_|IMG_)([0-9]{8}_[0-9]{6})[0-9]*(_?\[?.*\]?)"
VALID_INPUT_EXTENSIONS = ['.jpg', '.jpeg', '.png']
FORMAT_DIGITS = 3

def main():
    parser = argparse.ArgumentParser(description='Rename files')
    parser.add_argument('--target-folder', '-tf', help='File or folder containing the images(s)', type=str)
    args = parser.parse_args()

    if args.target_folder:
        target_folder = args.target_folder
    else:
        target_folder = input("Enter the target folder\\file:\n")
        print()
    
    target_files = [f for f in os.listdir(target_folder) if any(f.endswith(ext) for ext in VALID_INPUT_EXTENSIONS)]
    
    main_list = []
    for in_file in target_files:
        result = re.search(INPUT_REGEX, in_file)
        if result:
            sort_by = result.group(2)
            append_info = result.group(3)
            my_val = {
                'orig': in_file,
                'append_info': append_info,
                'sort_by': sort_by
            }
            main_list.append(my_val)
    
    main_list.sort(key=lambda x: x['sort_by'])
    for i,in_val in enumerate(main_list):
        os.rename(os.path.join(target_folder, in_val['orig']), os.path.join(target_folder, f"{i:0{FORMAT_DIGITS}d}{append_info}"))
        print(f"{i:0{FORMAT_DIGITS}d}{append_info}")
    
if __name__ == "__main__":
    main()