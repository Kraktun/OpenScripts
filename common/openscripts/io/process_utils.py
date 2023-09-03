import subprocess


def execute_command(command_with_args, silent=False, return_output=False, shell=True):
    output_lines = []
    with subprocess.Popen(command_with_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, 
            universal_newlines=True, shell=shell, bufsize=1, encoding="utf-8") as proc:
        (out, err) = proc.communicate() # use communicate or we may get a deadlock
        if out is not None:
            for line in out:
                output_lines.append(line)
                if not silent:
                    print(line, end='')
        if err is not None:
            for line in err:
                output_lines.append(line)
                print(line, end='')

    if proc.returncode != 0:
        raise subprocess.CalledProcessError(proc.returncode, proc.args)
    
    if return_output:
        return "".join(output_lines)
