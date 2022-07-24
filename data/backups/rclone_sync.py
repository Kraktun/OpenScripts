import yaml
import os
import sys
import argparse

# add path to local libs
abspath = os.path.abspath(os.path.join(__file__, os.pardir, os.pardir))
dir_path = os.path.dirname(abspath)
sys.path.insert(0, dir_path)

from utils.io import drive_utils
from utils.io import process_utils

def load_config(config_path):
    with open(config_path, 'r') as ff:
        conf = yaml.safe_load(ff)
    return conf

def main():
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

    # list currently available drives
    curr_letters = drive_utils.list_drive_paths()
    curr_drives = []
    for letter in curr_letters:
        if letter == "C:\\":
            curr_name = "C"
        else:
            curr_name = drive_utils.get_name_by_drive_path(letter)
        if curr_name != "":
            curr_drives.append((letter, curr_name))
    
    print(f"Currently available drives (label: path):")
    [print(f"{d[1]}: {d[0]}") for d in curr_drives]
    input("\nPress Enter to continue\n")
    print()

    for fold in config_dic['folders']:
        fold_id = fold['id']
        print(f"\nSyncing id: {fold_id}")
        # drives with common path
        fold_has_common_paths = "path" in fold.keys()
        if fold_has_common_paths:
            # get common path
            fold_path = fold["path"]
            # list of the currently connected drives
            available_drives = []
            for fold_drive_name in fold["drives"]:
                # tuple (name, letter)
                fold_drive = [d[0] for d in curr_drives if d[1] == fold_drive_name]
                if len(fold_drive) > 0:
                    # drive in config is currently connected
                    available_drives.append((fold_drive_name, fold_drive))
            if len(available_drives) > 1:
                # build path of first drive available
                path_a = os.path.join(available_drives[0][1], fold_path)
                for dr in available_drives[1:]:
                    # build path of second to last drives
                    path_b = os.path.join(dr[1], fold_path)
                    print(f"Syncing drives: {available_drives[0][0]} -> {dr[0]}")
                    process_utils.execute_command([rclone_exe, sync_mode, path_a, path_b])
            else:
                print(f"Less than two drives available, skipping.")
        else:
            # distinct paths
            paths_list = fold["paths"]
            available_drives_path = []
            for path in paths_list:
                drive_name = path["drive"]
                drive_path = path["path"]
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
                    print(f"Syncing drives: {available_drives_path[0][0]} -> {dr[0]}")
                    process_utils.execute_command([rclone_exe, sync_mode, path_a, path_b])
            else:
                print(f"Less than two drives available, skipping.")
    print()

if __name__ == "__main__":
    main()