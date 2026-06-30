"""OTIO protocol stub for simulate.py (tests without VGA32 hardware)."""

from __future__ import annotations

import os
import struct
import sys


OTIO_SYNC = 0xF0
OTIO_ETX = 0xF1
OTIO_CMD_PING = 0x01
OTIO_CMD_LIST = 0x10
OTIO_CMD_FOPEN = 0x20
OTIO_CMD_FREAD = 0x21


def _chk(body: bytes) -> int:
    return sum(body) & 0xFF


def _frame(stat: int, payload: bytes) -> list[int]:
    body = bytes([0x01, stat, len(payload) & 0xFF, len(payload) >> 8]) + payload
    return [OTIO_SYNC, ord("O"), ord("T")] + list(body) + [_chk(body), OTIO_ETX]


class OtioStub:
    def __init__(self, root: str, sd_present: bool = True):
        self.root = root
        self.sd_present = sd_present
        self._tx: list[int] = []
        self._rx: list[int] = []
        self._capture = False

    def _passthrough(self, value: int) -> None:
        print(f"{chr(value)}", end="")
        sys.stdout.flush()

    def on_tx(self, value: int) -> None:
        if not self._capture:
            if value == OTIO_SYNC:
                self._capture = True
                self._tx = [value]
            else:
                self._passthrough(value)
            return

        self._tx.append(value)
        if value != OTIO_ETX or not self._tx or self._tx[0] != OTIO_SYNC:
            return

        raw = bytes(self._tx)
        self._tx.clear()
        self._capture = False
        if len(raw) < 9 or raw[1:3] != b"OT":
            for b in raw:
                self._passthrough(b)
            return
        self._handle_frame(raw)

    def pending(self) -> bool:
        return len(self._rx) > 0

    def read(self) -> int:
        return self._rx.pop(0)

    def _handle_frame(self, raw: bytes) -> None:
        cmd = raw[4]
        plen = raw[5] | (raw[6] << 8)
        payload = raw[7 : 7 + plen]
        if cmd == OTIO_CMD_PING:
            caps = 0x02 | (0x01 if self.sd_present else 0)
            resp = bytes([0x01, 2, 4, caps])
            self._rx.extend(_frame(0x00, resp))
        elif cmd == OTIO_CMD_LIST and self.sd_present:
            self._rx.extend(self._list(payload))
        elif cmd == OTIO_CMD_FOPEN and self.sd_present:
            self._rx.extend(self._fopen(payload))
        elif cmd == OTIO_CMD_FREAD and self.sd_present:
            self._rx.extend(self._fread(payload))
        elif cmd in (OTIO_CMD_LIST, OTIO_CMD_FOPEN, OTIO_CMD_FREAD):
            self._rx.extend(_frame(0x01, bytes([0x03])))
        else:
            self._rx.extend(_frame(0x01, bytes([0x05])))

    def _rel_path(self, payload: bytes) -> str:
        nul = payload.find(0)
        if nul < 0:
            return ""
        return payload[:nul].decode("ascii", errors="ignore")

    def _abs_path(self, rel: str) -> str:
        rel = rel.strip("/")
        return os.path.join(self.root, rel) if rel else self.root

    def _list(self, payload: bytes) -> list[int]:
        rel = self._rel_path(payload)
        off = 0
        if len(payload) >= 3:
            nul = payload.find(0)
            if nul >= 0 and nul + 3 <= len(payload):
                off = payload[nul + 1] | (payload[nul + 2] << 8)
        path = self._abs_path(rel)
        if not os.path.isdir(path):
            return _frame(0x01, bytes([0x01]))
        names = sorted(os.listdir(path), key=str.lower)
        dirs = sorted([n for n in names if os.path.isdir(os.path.join(path, n))], key=str.lower)
        files = sorted([n for n in names if os.path.isfile(os.path.join(path, n))], key=str.lower)
        ordered = dirs + files
        if rel:
            ordered = [".."] + ordered
        chunk = ordered[off : off + 4]
        out = bytearray()
        for name in chunk:
            is_dir = name == ".." or os.path.isdir(os.path.join(path, name))
            nb = name.encode("ascii")[:24]
            out.append(2 if is_dir else 1)
            out.append(len(nb))
            out.extend(nb)
            out.extend(b"\x00" * (24 - len(nb)))
        eof = off + len(chunk) >= len(ordered)
        return _frame(0x03 if eof else 0x00, bytes(out))

    def _fopen(self, payload: bytes) -> list[int]:
        rel = self._rel_path(payload)
        path = self._abs_path(rel)
        if not os.path.isfile(path):
            return _frame(0x01, bytes([0x01]))
        size = os.path.getsize(path)
        self._open_path = path
        return _frame(0x00, bytes([0, size & 0xFF, (size >> 8) & 0xFF, (size >> 16) & 0xFF, (size >> 24) & 0xFF]))

    def _fread(self, payload: bytes) -> list[int]:
        if not hasattr(self, "_open_path"):
            return _frame(0x01, bytes([0x06]))
        offset = struct.unpack_from("<I", payload, 1)[0]
        with open(self._open_path, "rb") as f:
            f.seek(offset)
            data = f.read(64)
        if not data:
            return _frame(0x03, b"")
        handle = payload[0]
        seq = (offset // 64) & 0xFF
        ln = len(data)
        chk = (handle + seq + ln + sum(data)) & 0xFF
        return [OTIO_SYNC, ord("O"), ord("D"), handle, seq, ln] + list(data) + [chk, OTIO_ETX]
