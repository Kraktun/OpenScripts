from PIL import Image
import os
from pathlib import Path

def ext_selection():
    out_exts = ["jpg", "png"]
    print(f"Choose output extension:")
    for i,e in enumerate(out_exts):
        print(f"{i} - {e}")
    o_ext = input()
    if not o_ext.isnumeric() or int(o_ext) > len(out_exts):
        print("Invalid output")
        return ext_selection()
    return out_exts[int(o_ext)]

def get_float(strg):
    while True:
        expected_float = input(strg)
        try:
            return float(expected_float)
        except:
            print("Invalid value.")

def main():
    target_folder = input("Enter the target folder\\file:\n")
    print()
    target_red = get_float("Enter the target reduction:\n")
    print()
    exts = ['.jpg', '.jpeg', '.png']

    if os.path.isfile(target_folder):
        target_folder_p = Path(target_folder)
        if target_folder_p.suffix in exts:
            target_files = [target_folder]
            target_folder = target_folder_p.parent
            print("Valid file detected")
        else:
            print("Invalid file detected")
            return
    else:
        target_files = [f for f in os.listdir(target_folder) if any(f.endswith(ext) for ext in exts)]
        target_folder = Path(target_folder)
        print(f"Folder detected: {len(target_files)} files to process")
    
    if len(target_files) == 0:
        print("No files to process.")
        return
    
    print()
    out_extension = "." + ext_selection()

    out_dir = target_folder / "processed"
    out_dir.mkdir(exist_ok=True)

    print()
    counter = 1
    for fl in target_files:
        print(f"[{counter}/{len(target_files)}]\tProcessing {fl}")
        s_image  = Image.open(target_folder / fl)
        out_size = [int(fl*target_red) for fl in s_image.size]
        out_image = s_image.resize(out_size, Image.ANTIALIAS)
        if out_extension == ".png":
            out_image.save(out_dir / f"{Path(fl).stem}_lr.png", format="PNG", compress_level=9)
        elif out_extension == ".jpg":
            out_image.save(out_dir / f"{Path(fl).stem}_lr.jpg", format="JPEG", quality=95)
        else:
            out_image.save(out_dir / f"{Path(fl).stem}_lr{out_extension}")
        counter = counter+1
        
    print("\nDone")

if __name__ == "__main__":
    main()