# OpenScripts

Collection of standalone scripts.   
Note that the `common` package is a shared library.   
All python scripts require Python >= 3.10.

To run python files install the common package as described in the readme in `common`.

The `linux` folder contains a collection of scripts used to install and configure some linux programs. They are usually used on arm boards (Armbian or Raspberry OS).
Refer to the Readme in the folder for further instructions.

## App

### Tachiyomi

#### Mangadex migrator

Simple script to migrate the indexes from the previous version of the site to the new ones. Does not require root, provided that the app is the debug version.
See the readme file in the folder for more information.

## Data

### Backups

#### Rclone sync

Script that, given a configuration file, allows to sync local drives with [rclone](https://rclone.org/).

The configuration requires to define the name of the label of each drive (i.e. the current letters are retrieved automatically), which is what you see in file explorer.

Should support both Windows and Linux, but was tested only on Windows 11.

The configuration for a given path to sync is as follows, if the drives have a common path to sync:

```yaml
id: "id_of_the_sync_element"
path: "path/to/the/folder/to/sync" # note that this is without the letter of the drive
arguments: "" # optional arguments for rclone at folder level
overwrite_mode: "copy" # optional setting to overwrite the current sync mode for this folder, either sync or copy
drives:
- "My drive 1" # drive labels
- "My drive 2"
- "My drive 3"
```

otherwise if different paths have to be synced:

```yaml
id: "my_unique_id"
arguments: "" # optional arguments for rclone at folder level
overwrite_mode: "copy"
paths:
- drive: "C" # use C only for the default drive in windows
    path: "Users\\my_name\\Downloads" # path to the folder to sync, remember to escape \\, or use /
    arguments: "" # optional arguments for rclone at drive level
- drive: "My drive 1"
    path: "path/to/another/folder"
- drive: "My drive 4"
    path: "path/to/another/folder/again"
```

refer to the example configuration for more details.

The configuration allows to define a global sync mode, which is either `sync` or `copy`, which can be overwritten at a folder level if necessary.

To check how the script would perform, add `-v --dry-run` to the rclone arguments at the global level.
It is possible also to use the usual rclone exclude, include or filters to refine the sync process.

Note that the script syncs the first available drive with all the others in the list of drives configured for a specific folder, so it is assumed that the first drive is the most up to date (otherwise modifications of a subsequent drive are not propagated to the previous drives).

Usage:

```text
rclone_sync.py [-h] [--config CONFIG] [--rclone_path RCLONE_PATH]

Sync utility

optional arguments:
  -h, --help            show this help message and exit
  --config CONFIG, -cfg CONFIG
                        Path to the configuration file
  --rclone_path RCLONE_PATH, -rp RCLONE_PATH
                        Path to rclone executable if not in PATH
```

## Media

### Audio

#### Podcasts

##### find_duplicates

Simple script that can be easily adapted to find generic files with the same name in a folder.
For every duplicate it shows the path and the bitrate of the files to pick one of the two and remove the other.

##### retag

Script to automatically set tags of audio files based on the path of the file in the form `AUTHOR_NAME / ALBUM_NAME / my_file.m4a`. Currently supports only m4a files, but it can be easily adapted (with a different library) to other formats.

Includes also an automatic procedure to remove special characters and symbols from the names, if enabled.

### Novel

#### Novel organizer

Script to organize a set of ...known... novel files so that only one copy of each file is kept.

The filtering process relies on a external list of filters that is provided in order of preference (from best to worst) so that the first match is the file that is kept.

The filters may include both file extension and tags. Lines starting with `#` are treated as comments.
If multiple files have the same tag (e.g. multiple epub files) the following tags are used to choose the best option.

The script also includes a function to easily print the complete list of tags present in the source directory.

Files are also organized in complete and ongoing series.

Files can be either copied or moved during the filtering.

### Photo

#### Edit

##### Lower resolution

Script to lower the resolution of images, either with a fixed size (e.g. `1920x1080`) or as a ratio of the original (in the range 0-1).

Usage:

```text
lower_res.py [-h] [--target-folder TARGET_FOLDER] [--ratio RATIO] [--target-size TARGET_SIZE] [--output-extension OUTPUT_EXTENSION] [--output-folder OUTPUT_FOLDER]

Reduce resolution of one or more images

optional arguments:
  -h, --help            show this help message and exit
  --target-folder TARGET_FOLDER, -tf TARGET_FOLDER
                        File or folder containing the images(s)
  --ratio RATIO, -r RATIO
                        Target reduction in (0, 1)
  --target-size TARGET_SIZE, -ts TARGET_SIZE
                        Set a common target size for all images defined as "width"x"height" (without quotes)
  --output-extension OUTPUT_EXTENSION, -oe OUTPUT_EXTENSION
                        Output extension for the image(s)
  --output-folder OUTPUT_FOLDER, -of OUTPUT_FOLDER
                        Output folder for the processed image(s)
```

#### Unexifier

Remove exif information from a photo (i.e. location, device used etc.).

Usage:

```text
unexifier.py [-h] [--target-folder TARGET_FOLDER] [--output-folder OUTPUT_FOLDER] [--output-extension OUTPUT_EXTENSION]

Remove exif info from one or more images

optional arguments:
  -h, --help            show this help message and exit
  --target-folder TARGET_FOLDER, -tf TARGET_FOLDER
                        File or folder containing the images(s)
  --output-folder OUTPUT_FOLDER, -of OUTPUT_FOLDER
                        Output folder for the processed image(s)
  --output-extension OUTPUT_EXTENSION, -oe OUTPUT_EXTENSION
                        Output extension for the image(s)
```

## Misc

### Sort and rename

This script was used to sort images collected from two sources that used different filenames (`IMG_date_time` and `PXL_date_time`) according to the date in the filename. Given its very specific use case it is not really reusable, but I'll leave it here.
