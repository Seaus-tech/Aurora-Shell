#!/usr/bin/env python3
import sys
import re
import subprocess
import shutil

def progress_bar(label, percent, width=40):
    filled = int(width * percent / 100)
    bar = '━' * filled + ' ' * (width - filled)
    return f"\r  {label}\n  {percent:3.0f}% \033[32m{bar}\033[0m"

def run_brew(args):
    cmd = [shutil.which('brew') or '/usr/bin/brew'] + args
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    
    current_file = None
    for line in proc.stdout:
        # Detect download lines like: ✔︎ Bottle gh (2.92.0) Downloaded 13.1MB/ 13.1MB
        dl_match = re.search(r'Downloaded\s+([\d.]+)(MB|KB|GB)/\s*([\d.]+)(MB|KB|GB)', line)
        if dl_match:
            done = float(dl_match.group(1))
            total = float(dl_match.group(3))
            pct = min(100, (done / total * 100)) if total > 0 else 100
            label = current_file or line.strip()
            bar_width = 40
            filled = int(bar_width * pct / 100)
            bar = '━' * filled + ' ' * (bar_width - filled)
            size = f"{done}{dl_match.group(2)}/{total}{dl_match.group(4)}"
            sys.stdout.write(f"  {label}\n  {pct:3.0f}% \033[32m{'━' * filled}{' ' * (bar_width - filled)}\033[0m {size}\n")
            sys.stdout.flush()
            continue
        
        # Track what's being downloaded
        if 'Bottle' in line or 'Downloading' in line:
            m = re.search(r'(\w[\w\-\.]+)\s+\(', line)
            if m:
                current_file = m.group(1)
        
        sys.stdout.write(line)
        sys.stdout.flush()
    
    proc.wait()
    return proc.returncode

if __name__ == '__main__':
    sys.exit(run_brew(sys.argv[1:]))
