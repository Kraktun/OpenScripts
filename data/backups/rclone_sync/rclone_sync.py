import yaml
import os
import argparse
import re
import datetime 

# load local libs
from openscripts.io import drive_utils
from openscripts.io import process_utils
from DriveObject import DriveObject

DATE_TIME_REGEX = "\$datetime{(.*?)}"
global OUTPUT_FILE # path to the log file
OUTPUT_FILE = None

def load_config(config_path):
    # load yaml configuration
    with open(config_path, 'r') as ff:
        conf = yaml.safe_load(ff)
    return conf

def load_key_or_default(dict, key, default="", ignore_empty=False):
    # given a dictionary, check if a key exists, if it exists return it, otherwise return the 'default' param
    # if ignore_empty is true return the default parameter also if the key is present but is an empty string or list
    if key in dict.keys():
        val = dict[key]
        # return default if it is not a number or bool (bool is a subclass of int) and is either an empty string or an empty list
        if ignore_empty and not isinstance(val, (int, float)) and (len(dict[key])==0):
            return default
        return dict[key]
    else:
        return default

def empty_list_on_empty_string(s, split_on=" "):
    # split a string on a given subset of characters
    # if the string is empty return an empty list
    return s.split(split_on) if s.strip() != "" else []

def print_and_log(my_string, skip_stdout=False):
    # print a string to stdout and write it to the global OUTPUT_FILE
    # if skip_stdout is true, only write to OUTPUT_FILE
    if not skip_stdout: 
        print(my_string)
    if OUTPUT_FILE is not None:
        with open(OUTPUT_FILE, 'a', encoding="utf-8") as of:
                of.write(f"\n{my_string}")

def main():
    global OUTPUT_FILE
    print()
    current_datetime = datetime.datetime.now()
    # load config
    parser = argparse.ArgumentParser(description='Sync utility')
    parser.add_argument('--config', '-cfg', help='Path to the script configuration file', type=str)
    parser.add_argument('--rclone_path', '-rp', help='Path to rclone executable if not in PATH', type=str)
    args = parser.parse_args()

    if args.config:
        config_path = args.config
    else:
        config_path = input("Enter the path to the script configuration file:\n")
        print()
    config_dic = load_config(config_path)

    rclone_exe = "rclone"
    if args.rclone_path:
        rclone_exe = os.path.join(args.rclone_path, rclone_exe)

    # get sync mode
    sync_mode = config_dic['config']['sync_mode']
    assert sync_mode in ['copy', 'sync'], "Invalid sync mode"
    # get list all drives option
    extended_list_drives = load_key_or_default(config_dic['config'], 'extended_drive_search', default=False, ignore_empty=True)
    # get rclone global args
    rclone_global_args = load_key_or_default(config_dic['config'], 'arguments', default="", ignore_empty=False)
    rclone_global_args = empty_list_on_empty_string(rclone_global_args, split_on=" ")
    # get output_file
    OUTPUT_FILE = load_key_or_default(config_dic['config'], 'output_file', default=None, ignore_empty=True)
    # check if placeholders are used for date and time
    def replace_regex_with_format(match_obj):
        datetime_format = match_obj.group(1)
        return current_datetime.strftime(datetime_format)
    if OUTPUT_FILE is not None:       
        OUTPUT_FILE = re.sub(DATE_TIME_REGEX, replace_regex_with_format, OUTPUT_FILE)

    print_and_log(f"Starting rclone sync @ {current_datetime.strftime('%Y/%m/%d %H:%M:%S')}")
    
    # list currently available drives
    print_and_log("Collecting drive info. If there are network shares, it may take a while.")
    curr_letters = drive_utils.list_drive_paths(list_all=extended_list_drives)
    curr_drives = []
    for letter in curr_letters:
        if letter == "C:\\":
            curr_name = "C"
        else:
            curr_name = drive_utils.get_name_by_drive_path(letter)
        if curr_name != "":
            curr_drives.append((letter, curr_name))
    curr_names = [c[1] for c in curr_drives]
    
    print_and_log(f"\nCurrently available drives (label: path):")
    [print_and_log(f"{d[1]:>15}:   {d[0]}") for d in curr_drives]
    input("\nPress Enter to continue\n")
    print()

    for fold in config_dic['folders']:
        fold_id = fold['id']
        print_and_log(f"\nSyncing id: {fold_id}")
        # drives with common path
        fold_has_common_paths = "path" in fold.keys()

        if fold_has_common_paths:
            # get common path
            fold_path = fold["path"]
            # get arguments
            rclone_args = load_key_or_default(fold, "arguments", default="")
            rclone_args = empty_list_on_empty_string(rclone_args, split_on=" ")
            rclone_final_args = rclone_global_args[:] # slice to make a copy
            rclone_final_args.extend(rclone_args)
            rclone_final_args = [re.sub(DATE_TIME_REGEX, replace_regex_with_format, arr) for arr in rclone_final_args]
            # get optional overwrite mode
            rclone_current_mode = load_key_or_default(fold, 'overwrite_mode', sync_mode, ignore_empty=True)

            # list of the currently connected drives or remotes
            available_drives = [DriveObject(drive_name, curr_drives, path=fold_path) for drive_name in fold["drives"] if drive_name in curr_names]

            _process_available_drives(available_drives, rclone_exe, rclone_current_mode, rclone_final_args)

        else:
            # distinct paths
            paths_list = fold["paths"]
            # get arguments
            rclone_args = load_key_or_default(fold, "arguments", default="")
            rclone_args = empty_list_on_empty_string(rclone_args, split_on=" ")
            rclone_path_args = rclone_global_args[:] # slice to make a copy
            rclone_path_args.extend(rclone_args) 
            # get optional overwrite mode
            rclone_current_mode = load_key_or_default(fold, 'overwrite_mode', sync_mode, ignore_empty=True)

            # list of the currently connected drives or remotes
            available_drives = []
            for path in paths_list:
                drive_name = path["drive"]
                drive_path = path["path"]
                rclone_drive_args = load_key_or_default(path, "arguments", default="")
                rclone_drive_args = empty_list_on_empty_string(rclone_drive_args, split_on=" ")
                rclone_final_args = rclone_path_args[:]
                rclone_final_args.extend(rclone_drive_args)
                rclone_final_args = [re.sub(DATE_TIME_REGEX, replace_regex_with_format, arr) for arr in rclone_final_args]

                if drive_name in curr_names:
                    available_drives.append(DriveObject(drive_name, curr_drives, path=drive_path))

            _process_available_drives(available_drives, rclone_exe, rclone_current_mode, rclone_final_args)
    print_and_log("")

def _process_available_drives(available_drives, rclone_exe, rclone_current_mode, rclone_final_args):
    if len(available_drives) > 1:
        # no need to build the path: it is done at object initialization
        path_a = available_drives[0].path 
        for dr in available_drives[1:]:
            path_b = dr.path
            print_and_log(f"Syncing drives: {available_drives[0].drive_name} -> {dr.drive_name}")
            output_print = process_utils.execute_command([rclone_exe, rclone_current_mode, path_a, path_b, *rclone_final_args], return_output=True)
            print_and_log(output_print, skip_stdout=True)
    else:
        print_and_log(f"Less than two drives available, skipping.")

if __name__ == "__main__":
    main()