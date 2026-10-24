# Copyright 2026 The Tesseract Authors
# You can use, redistribute, and/or modify this source code under
# the terms of the GPL-3.0 license that can be found in the LICENSE file.
"""Parsers for macOS top, vm_stat and powermetrics output."""

import re

VM_STAT_KEYS = {
    'Swapins': 'swapins',
    'Swapouts': 'swapouts',
    'Pages stored in compressor': 'pages_compressed',
}


def parse_top_power(text, process_prefix):
    """
    Sums the POWER column of processes whose name starts with process_prefix,
    from the last sample of `top -l N -stats pid,command,power`.
    top truncates COMMAND to 16 characters, so match on a short prefix.
    """
    last_sample = text.split('PID    COMMAND')[-1].splitlines()[1:]
    total = 0.0
    for line in last_sample:
        match = re.match(r'\s*\d+\s+(.{1,16}?)\s+([\d.]+)\s*$', line)
        if match and match.group(1).startswith(process_prefix):
            total += float(match.group(2))
    return total


def parse_vm_stat(text):
    """Reads swap and compressor counters from `vm_stat`."""
    values = {}
    for line in text.splitlines():
        label, _, value = line.partition(':')
        key = VM_STAT_KEYS.get(label.strip().strip('"'))
        if key:
            values[key] = int(value.strip().rstrip('.'))
    return values


def parse_powermetrics_tasks(text, process_prefix):
    """
    Sums the Energy Impact column (the last one) of tasks whose name starts
    with process_prefix, from `powermetrics --samplers tasks`.
    """
    total = 0.0
    in_tasks = False
    for line in text.splitlines():
        if line.startswith('Name '):
            in_tasks = True
            continue
        if not in_tasks or not line.strip():
            continue
        if line.startswith('***'):
            break
        match = re.match(r'(.+?)\s+(-?\d+)\s+[\d.]+\s.*?([\d.]+)\s*$', line)
        if not match or match.group(1) == 'ALL_TASKS':
            continue
        if match.group(1).startswith(process_prefix):
            total += float(match.group(3))
    return total
