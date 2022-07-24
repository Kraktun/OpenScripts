from utils.global_utils import is_linux, is_windows
from .process_utils import execute_command
import psutil

if is_windows():
    import win32api

def list_drive_paths():
    # if is_windows():
    #     drives = win32api.GetLogicalDriveStrings()
    #     drives = drives.split('\000')[:-1]
    #     return drives
    drives = psutil.disk_partitions(all=True)
    drives_paths = [d.mountpoint for d in drives if "cdrom" not in d.opts]
    return drives_paths

def get_name_by_drive_path(path):
    if is_windows():
        try:
            return win32api.GetVolumeInformation(path)[0]
        except Exception:
            return ""
    elif is_linux():
        res = execute_command(["lsblk", "-o", "label,mountpoint"], silent=True, return_output=True, shell=False)
        res = res[1:] # skip first line with legend
        res_nonempty = [r for r in res if r.strip("\n").strip()] # remove empty lines, sort of
        res_labeled = [r.strip("\n") for r in res_nonempty if r[0] != " "] # keep only where a label is present
        # assume labels have no space or I don't know how it behaves (does it add quotes?)
        res_labeled = [r.split(" ") for r in res_labeled]
        for r in res_labeled:
            if r[1] == path:
                return r[0]
        return ""

if __name__ == "__main__":
    d = list_drive_paths()
    #n = get_name_by_drive_path(d[0])
    print(d)

