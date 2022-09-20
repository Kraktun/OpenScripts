import os
import posixpath

REMOTE_PREFIX = "*"

class DriveObject:
    def __init__(self, drive_name, curr_drives, path=""):
        # curr_drives is the list of tuples of drives in the format (drive_name, letter)
        self.drive_name = drive_name
        fold_drive = [d[0] for d in curr_drives if d[1] == drive_name]
        if len(fold_drive) > 0:
            # drive in config is currently connected
            self.drive_letter = fold_drive[0]
            self.is_remote = False
        elif drive_name[0] == REMOTE_PREFIX:
            # drive is a remote, so append it and use as letter the remote name (without the prepended *) and append :
            self.drive_letter = f"{drive_name[1:]}:"
            self.is_remote = True
        
        self.path = self.drive_letter
        if len(path) > 0:
            self._build_path(path)
        
    def _build_path(self, append_path):
        if self.is_remote:
            # posixpath and path remove the remote identifier
            if self.path == self.drive_letter:
                self.path = self.drive_letter + append_path.replace("\\", "/")
            else:
                self.path = self.drive_letter + posixpath.join(self.path, append_path.replace("\\", "/"))
        else:
            self.path = os.path.join(self.path, append_path)
        return self.path
