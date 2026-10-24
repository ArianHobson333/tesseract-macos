#!/usr/bin/env python3

# Copyright 2026 The Tesseract Authors
# You can use, redistribute, and/or modify this source code under
# the terms of the GPL-3.0 license that can be found in the LICENSE file.
"""
Opens the 50-page corpus in a browser, then samples energy and memory
pressure once a minute. Chromium browsers are driven over the DevTools HTTP
endpoint with a throwaway profile; others (Safari) use `open -a`.
"""

import argparse
import csv
import http.client
import json
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.parse
from pathlib import Path

from parse_metrics import parse_powermetrics_tasks, parse_top_power, parse_vm_stat

CDP_PORT = 9333
CORPUS = Path(__file__).parent / 'corpus.txt'
COLUMNS = ['t_min', 'browser', 'energy_impact', 'top_power', 'swapins', 'swapouts',
           'pages_compressed']


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--browser', type=Path, required=True, help='path to the .app')
    parser.add_argument('--minutes', type=int, default=60)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--process-prefix', action='append',
                        help='process name prefix to measure (repeatable); default: app name')
    parser.add_argument('--no-cdp', action='store_true',
                        help='open pages with `open -a` (for Safari)')
    return parser.parse_args()


def read_corpus():
    lines = CORPUS.read_text().splitlines()
    return [line.strip() for line in lines if line.strip() and not line.startswith('#')]


def cdp(method, path):
    conn = http.client.HTTPConnection('127.0.0.1', CDP_PORT, timeout=10)
    conn.request(method, path)
    body = conn.getresponse().read()
    conn.close()
    return json.loads(body) if body.startswith((b'{', b'[')) else body


def launch_chromium(app, urls, profile_dir):
    info = plistlib.loads((app / 'Contents' / 'Info.plist').read_bytes())
    executable = app / 'Contents' / 'MacOS' / info['CFBundleExecutable']
    process = subprocess.Popen([
        str(executable), f'--remote-debugging-port={CDP_PORT}',
        f'--user-data-dir={profile_dir}', '--no-first-run', '--no-default-browser-check',
        'about:blank'
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(30):
        try:
            cdp('GET', '/json/version')
            break
        except OSError:
            time.sleep(1)
    else:
        process.terminate()
        sys.exit('error: browser did not open the DevTools port')

    first = None
    for url in urls:
        target = cdp('PUT', '/json/new?' + urllib.parse.quote(url, safe=''))
        first = first or target['id']
        time.sleep(1)
    cdp('GET', f'/json/activate/{first}')
    return process


def launch_with_open(app, urls):
    for url in urls:
        subprocess.run(['open', '-a', str(app), url], check=True)
        time.sleep(1)


def powermetrics_available():
    return shutil.which('powermetrics') and subprocess.run(
        ['sudo', '-n', 'true'], capture_output=True).returncode == 0


def sample(prefixes, use_powermetrics):
    top = subprocess.run(['top', '-l', '2', '-s', '1', '-stats', 'pid,command,power'],
                         capture_output=True, text=True).stdout
    vm = parse_vm_stat(subprocess.run(['vm_stat'], capture_output=True, text=True).stdout)
    energy = ''
    if use_powermetrics:
        tasks = subprocess.run(
            ['sudo', '-n', 'powermetrics', '--samplers', 'tasks', '-n', '1', '-i', '1000'],
            capture_output=True, text=True).stdout
        energy = sum(parse_powermetrics_tasks(tasks, p) for p in prefixes)
    power = sum(parse_top_power(top, p[:16]) for p in prefixes)
    return energy, power, vm


def main():
    args = parse_args()
    app = args.browser.resolve()
    name = app.stem
    prefixes = args.process_prefix or [name]
    use_powermetrics = powermetrics_available()
    if not use_powermetrics:
        print('warning: no passwordless sudo for powermetrics; energy_impact left empty '
              '(run `sudo -v` first to include it)', file=sys.stderr)

    urls = read_corpus()
    profile_dir = tempfile.mkdtemp(prefix='perf-profile-')
    process = None
    if args.no_cdp:
        launch_with_open(app, urls)
    else:
        process = launch_chromium(app, urls, profile_dir)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    try:
        with args.out.open('w', newline='') as out:
            writer = csv.writer(out)
            writer.writerow(COLUMNS)
            for t_min in range(1, args.minutes + 1):
                time.sleep(60)
                energy, power, vm = sample(prefixes, use_powermetrics)
                writer.writerow([t_min, name, energy, power, vm['swapins'], vm['swapouts'],
                                 vm['pages_compressed']])
                out.flush()
                print(f'{t_min}/{args.minutes} min: power {power:.1f}')
    finally:
        if process:
            process.terminate()
        shutil.rmtree(profile_dir, ignore_errors=True)


if __name__ == '__main__':
    main()
