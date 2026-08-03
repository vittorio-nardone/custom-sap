# Kernel USB storage (CH376S)

FAT12/16/32 file access over a CH376S module wired to **ACIA #2**
(`0x6022` control/status, `0x6023` data, 115200 8N1).

The RD_USB_DATA0 burst is ROM resident (the kernel already lives in the 16-bit
address space, so no RAM copy is needed) and there is no EXTINT1 handler —
every command polls for the UART status byte.

Initialisation is lazy. Nothing touches ACIA #2 until the first `STORAGE_*`
call, so a machine without the module boots normally and simply gets `C=0`.

## Files

| File | Contents |
|------|----------|
| `const.asm` | CH376 opcodes, status codes, OT header and range constants |
| `io.asm` | ACIA #2 byte I/O, timeouts, delays, INT# clearing |
| `burst.asm` | `ch376_rd_usb_burst` — SEI receive loop for RD_USB_DATA0 |
| `proto.asm` | Command packets, file read/write engines |
| `range.asm` | `STORAGE_CHECK_RANGE` |
| `ot.asm` | OT header detect / emit |
| `api.asm` | Public `STORAGE_*` API |
| `menu.asm` | Kernel `l` (load) and `w` (write) commands |

RAM variables are declared in `kernel/memmap.asm`:

* `0x8284-0x82AF` — hot RX path. Must stay in the 16-bit space: ACIA #2 has a
  one byte RX FIFO and at 115200 baud the burst has ~87us per byte, which
  24-bit addressing does not meet.
* `0x82B0-0x82EF` — driver state, path buffer (`CH376_FNBUF`).
* `0xDC00` — `STORAGE_NAMES`, the 40 x 16 byte browser table (8.3 + size +
  flags). `STORAGE_LFN` at `0xDE80` holds optional display names (40 x 32).
  Both live in application RAM (`0xDC00–0xE37F`) and are only valid while the
  kernel USB menu is running — menu `l`/`w` will overwrite that range.

## API

All entry points return `C=1` on success and `C=0` on failure. On failure the
CH376 interrupt status is left in `CH376_LAST_STATUS` (`0x42` = file not found,
`0x41` = the name is a directory).

| Symbol | Inputs | Description |
|--------|--------|-------------|
| `STORAGE_INIT` | — | Reset ACIA #2, probe the module, set `STORAGE_ST_PRESENT` |
| `STORAGE_MOUNT` | — | USB host mode, connect and mount; sets `STORAGE_ST_MOUNTED` |
| `STORAGE_ENSURE_MOUNTED` | — | Mount only if not mounted yet |
| `STORAGE_STATUS` | — | `A` = `STORAGE_ST_*` flags |
| `STORAGE_SET_NAME` | `Y:D:E` | Set the working path (null terminated, upper-cased on the wire) |
| `STORAGE_OPEN` | — | Open the current path |
| `STORAGE_CREATE` | — | Create/truncate the current path |
| `STORAGE_CLOSE` | `A` | Close; `A=1` updates the file size |
| `STORAGE_READ` | `Y:D:E`, `CH376_REMAIN_LO/HI` | Read into memory; bytes stored in `CH376_LOADED_LO/HI` |
| `STORAGE_WRITE` | `Y:D:E`, `CH376_REMAIN_LO/HI` | Write raw bytes from memory |
| `STORAGE_CHECK_RANGE` | `Y:D:E`, `CH376_REMAIN_LO/HI` | Reject I/O, video and wrapping ranges |
| `STORAGE_LOAD_FILE` | see below | Open, strip the OT header, place the payload |
| `STORAGE_SAVE_FILE` | see below | Create and write a memory range |

### `STORAGE_LOAD_FILE`

Inputs: path in `CH376_FNBUF`, size in `CH376_TOTAL_LO/HI`, `CH376_OT_AUTO`
(1 = take the address from the OT header, 0 = use `STORAGE_ADDR_PAGE/MSB/LSB`).

The OT rules match the XMODEM loader: a `4F 54 01 page hi lo` header is always
stripped, but only supplies the destination when `CH376_OT_AUTO` is set. With
auto mode and no header the payload goes to `0x8400`.

Outputs: `STORAGE_LOAD_PTRP/H/PTR` (effective address), `CH376_LOADED_LO/HI`
(bytes stored) and `CH376_OT_FOUND`.

### `STORAGE_SAVE_FILE`

Inputs: path in `CH376_FNBUF`, source in `CH376_SAVE_PAGE/MSB/LSB`, length in
`CH376_TOTAL_LO/HI`, `CH376_OT_FLAG` (1 = prepend an OT header describing the
source address). An existing file is truncated.

## Limits

* Transfers are 16-bit: 65535 bytes maximum (~64 KB).
* `0x6000-0x67FF` (device I/O) and `0x6800-0x7FFF` (video window) can never be
  a transfer endpoint, and a range may not wrap past `0xFFFF` into another page.
* Paths opened on the wire are still 8.3 FAT names. The menu lists a directory
  by opening it and `BYTE_READ`ing raw 32-byte FAT entries (including VFAT LFN
  slots). Wildcard `/*` enum cannot see LFN slots — that is a CH376 limitation.
  Display names are ASCII, truncated to 31 characters; open/select still uses
  the short alias.

## Menu commands

* `l` / `lyyxxxx` — browse and load. Without an address the OT header decides
  where the file lands (falling back to `0x8400`); with an address the header
  is stripped but the typed address wins. The default `d`/`r` address follows
  the load.
* `wyyxxxx` — write a memory range to a new file. Prompts for the length (hex)
  and an 8.3 name, and always prepends an OT header so `l` can restore it.

## Smoke test

`apps/storage_smoke.asm` mounts the stick, writes `/OTSMOKE.BIN` (1 KB of a
generated pattern), reads it back to a second buffer and compares.

In the simulator (virtual stick under `roms/sim/ch376/`):

```bash
source .venv/bin/activate
python simulate.py --ch376 --autorun --program roms/apps/current/asm/storage_smoke.bin \
  --max-cycles 8000000 --quiet
```

On hardware: CH376 module on ACIA #2 and a FAT-formatted USB stick.
