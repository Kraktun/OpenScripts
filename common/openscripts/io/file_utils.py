

def human_readable(num, suffix="B", divider=1024.0):
    if abs(num) < divider:
        return f"{num} {suffix}"
    else:
        num /= divider
    for unit in ["K", "M", "G", "T", "P", "E", "Z"]:
        if abs(num) < divider:
            return f"{num:3.2f} {unit}{suffix}"
        num /= divider
    return f"{num:.2f} Y{suffix}"
