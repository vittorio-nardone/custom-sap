#!/usr/bin/env python3
"""Add OT header (6 bytes) to a raw binary file.

Header format:
  0x4F 0x54  — magic "OT"
  0x01       — format version
  page       — load address page (24-bit high byte)
  hi         — load address MSB
  lo         — load address LSB
"""
import argparse


OT_MAGIC = bytes([0x4F, 0x54])
OT_VERSION = 0x01


def build_ot_header(address: int) -> bytes:
    return bytes([
        0x4F, 0x54, OT_VERSION,
        (address >> 16) & 0xFF,
        (address >> 8) & 0xFF,
        address & 0xFF,
    ])


def main():
    parser = argparse.ArgumentParser(description="Add OT header to a raw binary file")
    parser.add_argument("input", help="Input binary file")
    parser.add_argument("-o", "--output", help="Output file (default: overwrite input)")
    parser.add_argument("--address", type=lambda x: int(x, 0), default=0x8400,
                        help="Load address to encode in header (default: 0x8400)")
    args = parser.parse_args()

    with open(args.input, 'rb') as f:
        data = f.read()

    header = build_ot_header(args.address)
    output = args.output or args.input

    with open(output, 'wb') as f:
        f.write(header + data)


if __name__ == "__main__":
    main()
