from PIL import Image
import os
from pathlib import Path
import argparse

ACCEPTED_EXTENSIONS = [".jpg", ".png"] # i.e. extensions used to save the final file
VALID_INPUT_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.JPG'] # input file extensions

def ext_selection():
    print(f"Choose output extension:")
    for i,e in enumerate(ACCEPTED_EXTENSIONS):
        print(f"{i} - {e}")
    o_ext = input()
    if not o_ext.isnumeric() or int(o_ext) > len(ACCEPTED_EXTENSIONS):
        print("Invalid value")
        return ext_selection()
    return ACCEPTED_EXTENSIONS[int(o_ext)]

def main():
    parser = argparse.ArgumentParser(description='Remove exif info from one or more images')
    parser.add_argument('--target-folder', '-tf', help='File or folder containing the images(s)', type=str)
    parser.add_argument('--output-folder', '-of', help='Output folder for the processed image(s)', type=str)
    parser.add_argument('--output-extension', '-oe', help='Output extension for the image(s)', type=str)
    args = parser.parse_args()

    if args.target_folder:
        target_folder = args.target_folder
    else:
        target_folder = input("Enter the target folder\\file:\n")
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
    
    print()

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
        out_image = Image.new(s_image.mode, s_image.size)
        out_image.putdata(s_image.getdata())
        if out_extension == ".png":
            out_image.save(out_dir / f"{Path(fl).stem}.png", format="PNG", compress_level=9)
        elif out_extension == ".jpg":
            out_image.save(out_dir / f"{Path(fl).stem}.jpg", format="JPEG", quality=95)
        else:
            out_image.save(out_dir / f"{Path(fl).stem}{out_extension}")
        counter = counter+1
        
    print("\nDone")

if __name__ == "__main__":
    main()