import re
import os
import argparse

"""
Given an input regex, sort the files with the given regex and rename them in ascending order.
"""

DEFAULT_INPUT_REGEX = r"(PXL_|IMG_)([0-9]{8}_[0-9]{6})[0-9]*(_?\[?.*\]?)"
VALID_INPUT_EXTENSIONS = ['.jpg', '.jpeg', '.png']
# number of digits of the output files, e.g. if '3' the files will be renamed to 000.jpg, 001.jpg etc.
DEFAULT_FORMAT_DIGITS = 3

def main():
    parser = argparse.ArgumentParser(description='Rename files')
    parser.add_argument('--target-folder', '-tf', help='Folder containing the images', type=str)
    parser.add_argument('--format-digits', '-fd', help='Number of digits in the output filename', type=int)
    parser.add_argument('--input-regex', '-ir', help='Input regex for the sorting process', type=str)
    args = parser.parse_args()

    if args.target_folder:
        target_folder = args.target_folder
    else:
        target_folder = input("Enter the target folder:\n")
        print()
    if args.format_digits:
        format_digits = args.format_digits
    else:
        format_digits = DEFAULT_FORMAT_DIGITS
    if args.input_regex:
        input_regex = args.input_regex
    else:
        input_regex = DEFAULT_INPUT_REGEX
    
    target_files = [f for f in os.listdir(target_folder) if any(f.endswith(ext) for ext in VALID_INPUT_EXTENSIONS)]
    
    main_list = []
    for in_file in target_files:
        result = re.search(input_regex, in_file)
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
    for i, in_val in enumerate(main_list):
        os.rename(os.path.join(target_folder, in_val['orig']), os.path.join(target_folder, f"{i:0{format_digits}d}{append_info}"))
        print(f"{i:0{format_digits}d}{append_info}")
    
if __name__ == "__main__":
    main()