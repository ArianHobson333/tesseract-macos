# Copyright 2026 The Tesseract Authors
# You can use, redistribute, and/or modify this source code under
# the terms of the GPL-3.0 license that can be found in the LICENSE file.

from pathlib import Path

import pytest

from ..parse_metrics import parse_powermetrics_tasks, parse_top_power, parse_vm_stat

FIXTURES = Path(__file__).parent / 'fixtures'


def fixture(name):
    return (FIXTURES / name).read_text()


def test_top_power_sums_matching_rows_of_last_sample():
    assert parse_top_power(fixture('top_power.txt'), 'Tesseract') == pytest.approx(10.6)


def test_top_power_no_match_is_zero():
    assert parse_top_power(fixture('top_power.txt'), 'Safari') == 0.0


def test_vm_stat_reads_counters():
    assert parse_vm_stat(fixture('vm_stat.txt')) == {
        'swapins': 248377836,
        'swapouts': 258140641,
        'pages_compressed': 1590988,
    }


def test_powermetrics_sums_energy_impact_across_renderers():
    text = fixture('powermetrics_tasks.txt')
    assert parse_powermetrics_tasks(text, 'Tesseract Helper (Renderer)') == pytest.approx(26.0)
    assert parse_powermetrics_tasks(text, 'Tesseract') == pytest.approx(38.0)


def test_powermetrics_ignores_all_tasks_row():
    assert parse_powermetrics_tasks(fixture('powermetrics_tasks.txt'), 'ALL') == 0.0
