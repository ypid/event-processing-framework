#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# SPDX-FileCopyrightText: 2021 Robin Schneider <robin.schneider@geberit.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

"""
Convert ndjson (newline-delimited JSON streams) to YAML.

The idea is to replace all JSON files in this project with YAML.
The issue is that Rsyslog currently outputs JSON so it would be inconvenient
to convert that to YAML so lets stay with JSON for now.
"""

from __future__ import (print_function, unicode_literals,
                        absolute_import, division)

import argparse
import json

import yaml

__version__ = '0.1.0'
__maintainer__ = 'Robin Schneider <robin.schneider@geberit.com>'


def main():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument(
        'file',
        nargs='+',
        help="NDJSON file to convert.",
    )
    cli_args = args_parser.parse_args()

    for ndjson_file in cli_args.file:
        with open(ndjson_file, 'r') as fh:
            for line in fh.readlines():
                obj = json.loads(line)
                print(yaml.dump(obj))


if __name__ == '__main__':
    main()
