# custom-sap

## Control words ROM generation
```sh
python microcode.py
```

## ROM generation
```sh
customasm kernel.asm -f intelhex -o roms/kernel-rom.hex
```

## Requirements

### Rust & customasm installation
```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

cargo install customasm
```

### Python library IntelHex
```sh
pip install intelhex
```