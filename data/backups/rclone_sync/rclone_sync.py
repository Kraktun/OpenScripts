import yaml
import os
import sys
import argparse
import re
import datetime 

# add path to local libs
abspath = os.path.abspath(os.path.join(__file__, os.pardir, os.pardir, os.pardir))
dir_path = os.path.dirname(abspath)
sys.path.insert(0, dir_path)

from common.io import drive_utils
from common.io import process_utils

DATE_TIME_REGEX = "\$datetime{(.*?)}"
global OUTPUT_FILE
OUTPUT_FILE = None

def load_config(config_path):
    with open(config_path, 'r') as ff:
        conf = yaml.safe_load(ff)
    return conf

def load_key_or_default(dict, key, default="", ignore_empty=False):
    if key in dict.keys():
        val = dict[key]
        # return default if it is not a number and is either an empty string or an empty list
        if ignore_empty and not (type(val) == int or type(val) == float) and (len(dict[key])==0):
            return default
        return dict[key]
    else:
        return default

def empty_list_on_empty_string(s, split_on=" "):
    if s.strip() == "":
        return []
    else:
        return s.split(split_on)

def print_and_log(my_string, skip_stdout=False):
    if not skip_stdout: 
        print(my_string)
    if OUTPUT_FILE is not None:
        with open(OUTPUT_FILE, 'a') as of:
                of.write(f"\n{my_string}")

def main():
    global OUTPUT_FILE
    print()
    current_datetime = datetime.datetime.now()
    # load config
    parser = argparse.ArgumentParser(description='Sync utility')
    parser.add_argument('--config', '-cfg', help='Path to the configuration file', type=str)
    parser.add_argument('--rclone_path', '-rp', help='Path to rclone executable if not in PATH', type=str)
    args = parser.parse_args()

    if args.config:
        config_path = args.config
    else:
        config_path = input("Enter the path to the configuration file:\n")
        print()
    config_dic = load_config(config_path)

    rclone_exe = "rclone"
    if args.rclone_path:
        rclone_exe = os.path.join(args.rclone_path, rclone_exe)

    # get sync mode
    sync_mode = config_dic['config']['sync_mode']
    assert sync_mode in ['copy', 'sync'], "Invalid sync mode"
    # get rclone global args
    rclone_global_args = load_key_or_default(config_dic['config'], 'arguments', "")
    rclone_global_args = empty_list_on_empty_string(rclone_global_args, split_on=" ")
    # get output_file
    OUTPUT_FILE = load_key_or_default(config_dic['config'], 'output_file', None, ignore_empty=True)
    # check if placeholders are used for date and time
    if OUTPUT_FILE is not None:
        def replace_regex_with_format(match_obj):
            datetime_format = match_obj.group(1)
            return current_datetime.strftime(datetime_format)
        
        OUTPUT_FILE = re.sub(DATE_TIME_REGEX, replace_regex_with_format, OUTPUT_FILE)

    print_and_log(f"Starting rclone sync @ {current_datetime.strftime('%Y/%m/%d %H:%M:%S')}")
    
    # list currently available drives
    print_and_log("Collecting drive info. If there are network shares, it may take a while.")
    curr_letters = drive_utils.list_drive_paths()
    curr_drives = []
    for letter in curr_letters:
        if letter == "C:\\":
            curr_name = "C"
        else:
            curr_name = drive_utils.get_name_by_drive_path(letter)
        if curr_name != "":
            curr_drives.append((letter, curr_name))
    
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
            # get optional overwrite mode
            rclone_current_mode = load_key_or_default(fold, 'overwrite_mode', sync_mode, ignore_empty=True)

            # list of the currently connected drives
            available_drives = []
            for fold_drive_name in fold["drives"]:
                # tuple (name, letter)
                fold_drive = [d[0] for d in curr_drives if d[1] == fold_drive_name]
                if len(fold_drive) > 0:
                    # drive in config is currently connected
                    available_drives.append((fold_drive_name, fold_drive[0]))
            if len(available_drives) > 1:
                # build path of first drive available
                path_a = os.path.join(available_drives[0][1], fold_path)
                for dr in available_drives[1:]:
                    # build path of second to last drives
                    path_b = os.path.join(dr[1], fold_path)
                    print_and_log(f"Syncing drives: {available_drives[0][0]} -> {dr[0]}")
                    output_print = process_utils.execute_command([rclone_exe, rclone_current_mode, path_a, path_b, *rclone_final_args], return_output=True)
                    print_and_log("".join(output_print), skip_stdout=True)
            else:
                print_and_log(f"Less than two drives available, skipping.")

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

            available_drives_path = []
            for path in paths_list:
                drive_name = path["drive"]
                drive_path = path["path"]
                rclone_drive_args = load_key_or_default(path, "arguments", default="")
                rclone_drive_args = empty_list_on_empty_string(rclone_drive_args, split_on=" ")
                rclone_final_args = rclone_path_args[:]
                rclone_final_args.extend(rclone_drive_args)

                # check if drive is present
                drive_connected = [d[0] for d in curr_drives if d[1] == drive_name]
                if len(drive_connected) > 0:
                    # tuple name, letter, path
                    available_drives_path.append((drive_name, drive_connected[0], drive_path))
            if len(available_drives_path) > 1:
                # build path of first drive available
                path_a = os.path.join(available_drives_path[0][1], available_drives_path[0][2])
                for dr in available_drives_path[1:]:
                    # build path of second to last drives
                    path_b = os.path.join(dr[1], dr[2])
                    print_and_log(f"Syncing drives: {available_drives_path[0][0]} -> {dr[0]}")
                    output_print = process_utils.execute_command([rclone_exe, rclone_current_mode, path_a, path_b, *rclone_final_args], return_output=True)
                    print_and_log("".join(output_print), skip_stdout=True)
            else:
                print_and_log(f"Less than two drives available, skipping.")
    print_and_log("")

if __name__ == "__main__":
    main()