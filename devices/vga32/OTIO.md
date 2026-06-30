# OTIO Protocol v1 (Otto Terminal I/O)

Binary protocol on the Otto ACIA UART (115200 8N1) between Project Otto and ESP32 AdvancedTerminal.

## Command / response frame

```
F0 'O' 'T' VER CMD/STAT LEN_L LEN_H [PAYLOAD...] CHK F1
```

| Field | Value |
|-------|-------|
| SYNC | `0xF0` |
| Magic | `'O' 'T'` |
| VER | `0x01` |
| CMD | Otto → ESP32 |
| STAT | ESP32 → Otto (`0x00` OK, `0x01` ERR, `0x03` EOF, `0x04` NAK) |
| LEN | u16 LE |
| CHK | sum of VER..last payload byte, mod 256 |
| ETX | `0xF1` |

## Commands (v1)

| CMD | Name | Payload |
|-----|------|---------|
| `0x01` | PING | — |
| `0x10` | LIST | `path\0` + offset u16 LE |
| `0x20` | FOPEN | `path\0` |
| `0x21` | FREAD | handle u8 + offset u32 LE |
| `0x22` | FCLOSE | handle u8 |

PING response: `proto_ver, fw_maj, fw_min, caps` (caps bit0=SD, bit1=folders).

LIST entry (26 bytes): `type u8` (1=file, 2=dir), `name_len u8`, `name[24]`.

## Data chunk (after FOPEN)

```
F0 'O' 'D' HANDLE SEQ LEN [DATA 0..64] CHK F1
```

## SD layout

On the microSD (FAT32), copy **`roms/apps/`** from the repo to **`otto/apps/`** at the card root (e.g. `/otto/apps/asm/helloworld.bin`). The simulator `--otio-stub` defaults to `--otio-root roms` with the same relative paths.

## Error codes (ERR payload byte)

`0x01` not found, `0x02` not a file, `0x03` SD unavailable, `0x04` path too long, `0x05` invalid path, `0x06` SD I/O error.

## Testing

| Mode | Command |
|------|---------|
| Simulator only (stub SD) | `python simulate.py --otio-stub --input $'t\r'` |
| Simulator + VGA32 (FTDI) | `python simulate.py --otio-test --serial-device /dev/cu.*` |
| Interactive Mac-as-Otto | `python simulate.py --serial-device /dev/cu.*` |
| Otto hardware | Kernel menu: `t`, `l apps/asm`, `g helloworld.bin` |

`--otio-test` boots the kernel in the simulator, sends `t` + CR on the serial port (unless `--input` is set), then checks `OTIO_PEER_STATUS` / caps in kernel RAM. VGA32 AdvancedTerminal must already be running. Custom OTIO menu input: `--headless --serial-device … --input $'l apps/asm\r'`.
