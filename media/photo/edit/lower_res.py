from PIL import Image
import os
from pathlib import Path
import argparse

ACCEPTED_EXTENSIONS = [".jpg", ".png"] # i.e. extensions used to save the final file
VALID_INPUT_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.JPG'] # input file extensions

# note that exif info is not preserved

def ext_selection():
    print(f"Choose output extension:")
    for i,e in enumerate(ACCEPTED_EXTENSIONS):
        print(f"{i} - {e}")
    o_ext = input()
    if not o_ext.isnumeric() or int(o_ext) > len(ACCEPTED_EXTENSIONS):
        print("Invalid value")
        return ext_selection()
    return ACCEPTED_EXTENSIONS[int(o_ext)]

def get_float(strg):
    while True:
        expected_float = input(strg)
        try:
            fl = float(expected_float)
            if check_ratio(fl):
                return fl
            else:
                print("Invalid value")
                continue
        except:
            print("Invalid value")

def check_ratio(fl):
    # check if float provided is a valid ratio
    return fl > 0 and fl <= 1

def parse_size(size):
    if len(size.split("x")) < 2:
        return None
    width = size.split("x")[0]
    height = size.split("x")[1]
    try:
        width = int(width)
        height = int(height)
        if width < 1 or height < 1:
            return None
        return (width, height)
    except:
        return None

def main():
    # parse args
    parser = argparse.ArgumentParser(description='Reduce resolution of one or more images')
    parser.add_argument('--target-folder', '-tf', help='File or folder containing the images(s)', type=str)
    parser.add_argument('--ratio', '-r', help='Target reduction in (0, 1)', type=float)
    # if both ratio and size are defined, size is used
    parser.add_argument('--target-size', '-ts', help='Set a common target size for all images defined as "width"x"height" (without quotes)', type=str)
    parser.add_argument('--output-extension', '-oe', help='Output extension for the image(s)', type=str)
    parser.add_argument('--output-folder', '-of', help='Output folder for the processed image(s)', type=str)
    args = parser.parse_args()

    if args.target_folder:
        target_folder = args.target_folder
    else:
        target_folder = input("Enter the target folder\\file:\n")
        print()
    if not args.ratio and not args.target_size:
        # no ratio nor size provided: ask which one to use
        while True:
            print("Do you want to use a common ratio or size?")
            print("0 - Ratio")
            print("1 - Size")
            choice_rs = input("")
            if choice_rs in ["0", "1"]:
                use_ratio = choice_rs == "0"
                break
            else:
                print("Invalid value.")
    elif args.target_size:
        use_ratio = False
    elif args.ratio:
        use_ratio = True

    if args.ratio:
        target_red = args.ratio
        if not check_ratio(target_red):
            print("Invalid ratio argument.")
            target_red = get_float("Enter the target reduction in the interval (0, 1) with 1=original size:\n")
    elif use_ratio:
        target_red = get_float("Enter the target reduction in the interval (0, 1) with 1=original size:\n")
        print()
    if args.target_size:
        target_size = args.target_size
        while not parse_size(target_size):
            print("Invalid size argument.")
            target_size = input('Enter the target size as "width"x"height" (without quotes):\n')
            target_size = parse_size(target_size)
    elif not use_ratio:
        target_size = input('Enter the target size as "width"x"height" (without quotes):\n')
        target_size = parse_size(target_size)
        while not target_size:
            print("Invalid size argument.")
            target_size = input('Enter the target size as "width"x"height" (without quotes):\n')
            target_size = parse_size(target_size)
        print()
    if args.output_extension:
        out_extension = args.output_extension
        if out_extension[0] != ".":
            out_extension = "." + out_extension
        if out_extension not in ACCEPTED_EXTENSIONS:
            print("Invalid output extension argument.")
            out_extension = ext_selection()
    else:
        out_extension = ext_selection()
        print()

    # check if the target folder has valid files inside or is a valid file itself
    if os.path.isfile(target_folder):
        target_folder_p = Path(target_folder)
        if target_folder_p.suffix in VALID_INPUT_EXTENSIONS:
            target_files = [target_folder]
            target_folder = target_folder_p.parent
            print("Valid file detected")
        else:
            print("Invalid file detected")
            return
    else:
        target_files = [f for f in os.listdir(target_folder) if any(f.endswith(ext) for ext in VALID_INPUT_EXTENSIONS)]
        target_folder = Path(target_folder)
        print(f"Folder detected: {len(target_files)} files to process")
    
    if len(target_files) == 0:
        print("No files to process.")
        return

    if args.output_folder:
        out_dir = Path(args.output_folder)
    else:
        out_dir = target_folder / "processed"
    out_dir.mkdir(exist_ok=True)

    print()
    counter = 1
    for fl in target_files:
        print(f"[{counter}/{len(target_files)}]\tProcessing {fl}")
        s_image  = Image.open(target_folder / fl)
        if use_ratio:
            out_size = [int(fl*target_red) for fl in s_image.size]
            out_append_name = f"r{target_red}"
        else:
            out_size = target_size
            out_append_name = f"s{target_size[0]}x{target_size[1]}"
        out_image = s_image.resize(out_size, Image.ANTIALIAS)
        out_file = out_dir / f"{Path(fl).stem}_[{out_append_name}]{out_extension}"
        if out_extension == ".png":
            out_image.save(out_file, format="PNG", compress_level=9)
        elif out_extension == ".jpg":
            out_image.save(out_file, format="JPEG", quality=95)
        else:
            out_image.save(out_file)
        counter = counter+1
        
    print("\nDone")

if __name__ == "__main__":
    main()