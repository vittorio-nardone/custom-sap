"""
Minimal CH376S UART (Ch376msc) emulator for simulate.py.

Enough protocol for kernel STORAGE_* and menu l/w: mount, browse (/*),
file create/read/write, GET_STATUS.  Files live under a host directory
(default roms/sim/ch376/).
"""

from __future__ import annotations

from collections import deque
from pathlib import Path
import struct

SYNC1 = 0x57
SYNC2 = 0xAB

CMD_GET_IC_VER = 0x01
CMD_CHECK_EXIST = 0x06
CMD_GET_STATUS = 0x22
CMD_RD_USB_DATA0 = 0x27
CMD_SET_USB_MODE = 0x15
CMD_DISK_CONNECT = 0x30
CMD_DISK_MOUNT = 0x31
CMD_SET_FILE_NAME = 0x2F
CMD_FILE_OPEN = 0x32
CMD_FILE_ENUM_GO = 0x33
CMD_FILE_CREATE = 0x34
CMD_FILE_CLOSE = 0x36
CMD_BYTE_READ = 0x3A
CMD_BYTE_RD_GO = 0x3B
CMD_BYTE_WRITE = 0x3C
CMD_BYTE_WR_GO = 0x3D
CMD_WR_REQ_DATA = 0x2D

INT_SUCCESS = 0x14
INT_CONNECT = 0x15
INT_DISK_READ = 0x1D
INT_DISK_WRITE = 0x1E
CMD_RET_SUCCESS = 0x51
ERR_MISS_FILE = 0x42
ERR_OPEN_DIR = 0x41

DIR_ATTR_DIRECTORY = 0x10

ACIA_RX_FULL = 0x01
ACIA_TX_EMPTY = 0x02


def _fat_dir_entry(name: str, size: int, is_dir: bool) -> bytes:
    entry = bytearray(32)
    name = name.upper()
    if "." in name:
        base, ext = name.split(".", 1)
    else:
        base, ext = name, ""
    field = base[:8].ljust(8) + ext[:3].ljust(3)
    entry[0:11] = field.encode("ascii", errors="replace")
    entry[11] = DIR_ATTR_DIRECTORY if is_dir else 0x20
    struct.pack_into("<I", entry, 28, size & 0xFFFFFFFF)
    return bytes(entry)


class Ch376Sim:
    """CH376 on ACIA #2 (0x6022 status, 0x6023 data)."""

    def __init__(self, root_dir: str | Path):
        self.root = Path(root_dir).resolve()
        self.root.mkdir(parents=True, exist_ok=True)

        self.rx: deque[int] = deque()
        self._sync = 0
        self._collect_path = False
        self._path_buf = bytearray()
        self._pending_cmd: int | None = None
        self._param_lo: int | None = None

        self.mounted = False
        self._last_status = INT_SUCCESS
        self._set_name = ""

        self._open_mode: str | None = None
        self._open_path: Path | None = None
        self._file_pos = 0
        self._dir_entries: list[bytes] = []
        self._dir_index = 0
        self._pending_payload: bytes | None = None

        self._write_expect = 0
        self._write_buf = bytearray()
        self._byte_write_len = 0

    # ---- ACIA #2 -------------------------------------------------------------
    def read_status(self) -> int:
        status = ACIA_TX_EMPTY
        if self.rx:
            status |= ACIA_RX_FULL
        return status

    def read_data(self) -> int:
        return self.rx.popleft() if self.rx else 0x00

    def write_data(self, value: int) -> None:
        value &= 0xFF

        if self._write_expect > 0:
            self._write_buf.append(value)
            self._write_expect -= 1
            if self._write_expect == 0:
                self._finish_write_payload()
            return

        if self._pending_cmd is not None:
            self._feed_param(value)
            return

        if self._collect_path:
            if value == 0:
                self._collect_path = False
                self._set_name = self._path_buf.decode("ascii", errors="replace").upper()
                self._path_buf.clear()
            else:
                self._path_buf.append(value)
            return

        if value == SYNC1:
            self._sync = 1
        elif self._sync == 1:
            self._sync = 2 if value == SYNC2 else 0
        elif self._sync == 2:
            self._sync = 0
            self._dispatch_cmd(value)

    # ---- Responses -----------------------------------------------------------
    def _enqueue(self, *bytes_out: int) -> None:
        self.rx.extend(b & 0xFF for b in bytes_out)

    def _respond_status(self, code: int) -> None:
        self._last_status = code & 0xFF
        self._enqueue(code)

    def _respond_int(self, code: int) -> None:
        if code in (INT_DISK_READ, INT_DISK_WRITE):
            self._respond_status(code)
        else:
            self._last_status = code & 0xFF
            self._enqueue(CMD_RET_SUCCESS, code)

    def _queue_payload(self, data: bytes) -> None:
        self._pending_payload = data
        self._respond_status(INT_DISK_READ)

    def _send_rd_usb_data0(self) -> None:
        data = self._pending_payload or b""
        self._pending_payload = None
        self._enqueue(len(data) & 0xFF)
        if data:
            self._enqueue(*data)

    # ---- Paths ---------------------------------------------------------------
    def _resolve_path(self, name: str) -> Path | None:
        name = name.strip().upper()
        if name in ("", "/", "*", "/*"):
            return self.root
        if name.startswith("/"):
            rel = name.lstrip("/")
        else:
            rel = name
        if rel.endswith("/*"):
            rel = rel[:-2]
        parts = [p for p in rel.replace("\\", "/").split("/") if p and p != "."]
        path = self.root
        for part in parts:
            if part == "..":
                if path != self.root:
                    path = path.parent
            else:
                path = path / part
        return path

    def _build_dir_listing(self, directory: Path) -> list[bytes]:
        entries: list[bytes] = []
        try:
            items = sorted(directory.iterdir(), key=lambda p: p.name.lower())
        except OSError:
            return entries
        for item in items:
            if item.name.startswith("."):
                continue
            if item.is_dir():
                entries.append(_fat_dir_entry(item.name, 0, True))
            elif item.is_file():
                try:
                    size = item.stat().st_size
                except OSError:
                    size = 0
                entries.append(_fat_dir_entry(item.name, size, False))
        return entries

    def _open_directory(self, directory: Path) -> None:
        self._open_mode = "dir"
        self._open_path = directory
        self._dir_entries = self._build_dir_listing(directory)
        self._dir_index = 0
        if self._dir_entries:
            self._queue_payload(self._dir_entries[0])
            self._dir_index = 1
        else:
            self._respond_status(ERR_MISS_FILE)

    def _open_file(self, path: Path) -> None:
        if not path.is_file():
            self._respond_status(ERR_MISS_FILE)
            return
        self._open_mode = "file"
        self._open_path = path
        self._file_pos = 0
        self._respond_int(INT_SUCCESS)

    def _enum_next(self) -> None:
        if self._open_mode != "dir" or self._dir_index >= len(self._dir_entries):
            self._respond_status(ERR_MISS_FILE)
            return
        self._queue_payload(self._dir_entries[self._dir_index])
        self._dir_index += 1

    def _read_file_chunk(self, length: int) -> None:
        if self._open_mode != "file" or self._open_path is None:
            self._respond_status(ERR_MISS_FILE)
            return
        length = max(1, min(length, 0xFF))
        try:
            data = self._open_path.read_bytes()
        except OSError:
            self._respond_status(ERR_MISS_FILE)
            return
        chunk = data[self._file_pos : self._file_pos + length]
        self._file_pos += len(chunk)
        if chunk:
            self._queue_payload(chunk)
        else:
            self._respond_int(INT_SUCCESS)

    def _finish_write_payload(self) -> None:
        if self._open_path is None:
            return
        data = bytes(self._write_buf)
        self._write_buf.clear()
        try:
            if self._open_path.exists():
                existing = bytearray(self._open_path.read_bytes())
            else:
                existing = bytearray()
            end = self._file_pos + len(data)
            if end > len(existing):
                existing.extend(b"\x00" * (end - len(existing)))
            existing[self._file_pos : self._file_pos + len(data)] = data
            self._open_path.write_bytes(existing)
            self._file_pos += len(data)
        except OSError:
            self._respond_status(ERR_MISS_FILE)
            return
        self._respond_int(INT_SUCCESS)

    # ---- Commands ------------------------------------------------------------
    def _feed_param(self, value: int) -> None:
        cmd = self._pending_cmd
        if cmd == CMD_CHECK_EXIST:
            self._pending_cmd = None
            self._enqueue((value ^ 0xFF) & 0xFF)
            return
        if cmd == CMD_SET_USB_MODE:
            self._pending_cmd = None
            self._respond_status(INT_SUCCESS)
            return
        if cmd == CMD_FILE_CLOSE:
            self._pending_cmd = None
            self._open_mode = None
            self._open_path = None
            self._respond_status(INT_SUCCESS)
            return
        if cmd in (CMD_BYTE_READ, CMD_BYTE_WRITE):
            if self._param_lo is None:
                self._param_lo = value
                return
            length = self._param_lo | (value << 8)
            self._pending_cmd = None
            self._param_lo = None
            if cmd == CMD_BYTE_READ:
                self._read_file_chunk(length if length else 0x100)
            else:
                self._byte_write_len = length if length else 0x100
                self._write_buf.clear()
                self._respond_int(INT_DISK_WRITE)
            return

    def _dispatch_cmd(self, cmd: int) -> None:
        if cmd == CMD_SET_FILE_NAME:
            self._path_buf.clear()
            self._collect_path = True
            return
        if cmd == CMD_CHECK_EXIST:
            self._pending_cmd = cmd
            return
        if cmd == CMD_SET_USB_MODE:
            self._pending_cmd = cmd
            return
        if cmd in (CMD_BYTE_READ, CMD_BYTE_WRITE, CMD_FILE_CLOSE):
            self._pending_cmd = cmd
            self._param_lo = None
            return
        if cmd == CMD_RD_USB_DATA0:
            self._send_rd_usb_data0()
            return
        if cmd == CMD_GET_STATUS:
            self._respond_status(self._last_status)
            return
        if cmd == CMD_GET_IC_VER:
            self._enqueue(0x20)
            return
        if cmd == CMD_DISK_CONNECT:
            self._respond_status(INT_CONNECT if self.mounted else INT_SUCCESS)
            return
        if cmd == CMD_DISK_MOUNT:
            self.mounted = True
            self._respond_status(INT_SUCCESS)
            return
        if cmd == CMD_FILE_OPEN:
            self._handle_file_open()
            return
        if cmd == CMD_FILE_ENUM_GO:
            self._enum_next()
            return
        if cmd == CMD_FILE_CREATE:
            self._handle_file_create()
            return
        if cmd in (CMD_BYTE_RD_GO, CMD_BYTE_WR_GO):
            self._respond_int(INT_SUCCESS)
            return
        if cmd == CMD_WR_REQ_DATA:
            want = self._byte_write_len or 0x40
            self._enqueue(want & 0xFF)
            self._write_expect = want
            return
        self._respond_status(INT_SUCCESS)

    def _handle_file_open(self) -> None:
        name = self._set_name
        if name in ("/*", "*") or name.endswith("/*"):
            self._open_directory(self._resolve_path(name) or self.root)
            return
        path = self._resolve_path(name)
        if path is None:
            self._respond_status(ERR_MISS_FILE)
            return
        if path.is_dir():
            self._open_directory(path)
            return
        self._open_file(path)

    def _handle_file_create(self) -> None:
        path = self._resolve_path(self._set_name)
        if path is None:
            self._respond_status(ERR_MISS_FILE)
            return
        if path.is_dir():
            self._respond_status(ERR_OPEN_DIR)
            return
        self._open_mode = "file"
        self._open_path = path
        self._file_pos = 0
        self._write_buf.clear()
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"")
        except OSError:
            self._respond_status(ERR_MISS_FILE)
            return
        self._respond_int(INT_SUCCESS)
