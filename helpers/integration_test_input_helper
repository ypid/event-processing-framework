#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# SPDX-FileCopyrightText: 2023 Robin Schneider <ro.schneider@senec.com>
#
# SPDX-License-Identifier: AGPL-3.0-only

"""
TODO: Each input JSON must only contain one JSON object. Switch to YAML.
https://stackoverflow.com/questions/52019795/reading-file-that-contains-multiple-json-objects-python/52020334#52020334

Go though all files in tests/integration/input/ and update them as needed.

Features:
* Ensure event.sequence exists and is a random 17 digit number.
* TBD. Ensure proper sorting.
"""

import ndjson
from pathlib import Path

__version__ = "0.1.0"


def _update_test_input_file(filepath):
    print(filepath)
    with open(filepath, 'r') as read_fh:
        test_input = ndjson.load(read_fh)

    print(test_input)


def main():
    import argparse

    args_parser = argparse.ArgumentParser(description=__doc__)
    args_parser.add_argument("-d", "--dir", required=True)
    args_parser.add_argument(
        "-V", "--version", action="version", version="%(prog)s {}".format(__version__)
    )
    cli_args = args_parser.parse_args()

    pathlist = Path(cli_args.dir).glob("*.json")
    for path in pathlist:
        _update_test_input_file(path)


if __name__ == "__main__":
    main()
