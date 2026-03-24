#!/usr/bin/env python3
"""
Tiny Pascal Compiler for Project Otto P-Machine.

Compiles a minimal subset of Pascal into P-code bytecode
that runs on the Otto P-Machine interpreter (ROM #3).

MS1 subset: program structure, writeln/write with string literals.

Usage:
    python pascal_compiler.py input.pas -o output.bin [--base 0x8400]
"""

import sys
import argparse
from enum import Enum, auto
from dataclasses import dataclass
from typing import List, Optional

# ── P-code constants ────────────────────────────────────────

OP_HALT  = 0x00
OP_LIT   = 0x01
OP_LIT16 = 0x02
OP_CSP   = 0x10

CSP_WRITE         = 0x00
CSP_WRITELN       = 0x01
CSP_WRITELN_NOARG = 0x02

MAGIC = bytes([0x50, 0x4D])   # "PM"
FORMAT_VERSION = 0x01
PCODE_HEADER_SIZE = 7

# Native stub: Otto machine code that bootstraps the P-Machine.
# The stub sets D:E to the P-code header address then JSRs to PMACHINE_START.
#   LDD #nn          (0xA5, nn)        2 bytes
#   LDE #nn          (0xA6, nn)        2 bytes
#   JSR 0x4000       (0x20,0x40,0x00,0x00)  4 bytes  (zero-page JSR + pad)
#   RTS              (0x60)            1 byte
NATIVE_STUB_SIZE = 9
PMACHINE_ADDR = 0x4000

# ── Token types ─────────────────────────────────────────────

class TokenType(Enum):
    PROGRAM        = auto()
    BEGIN          = auto()
    END            = auto()
    WRITELN        = auto()
    WRITE          = auto()
    IDENTIFIER     = auto()
    STRING_LITERAL = auto()
    SEMICOLON      = auto()
    DOT            = auto()
    LPAREN         = auto()
    RPAREN         = auto()
    EOF            = auto()

KEYWORDS = {
    'program': TokenType.PROGRAM,
    'begin':   TokenType.BEGIN,
    'end':     TokenType.END,
    'writeln': TokenType.WRITELN,
    'write':   TokenType.WRITE,
}

@dataclass
class Token:
    type: TokenType
    value: str
    line: int
    col: int

# ── Lexer ───────────────────────────────────────────────────

class Lexer:
    def __init__(self, source: str):
        self.source = source
        self.pos = 0
        self.line = 1
        self.col = 1

    def _error(self, msg: str):
        raise SyntaxError(f"line {self.line}, col {self.col}: {msg}")

    def _advance(self):
        if self.pos < len(self.source):
            if self.source[self.pos] == '\n':
                self.line += 1
                self.col = 1
            else:
                self.col += 1
            self.pos += 1

    def _skip_whitespace_and_comments(self):
        while self.pos < len(self.source):
            ch = self.source[self.pos]
            if ch in ' \t\r\n':
                self._advance()
            elif ch == '{':
                self._advance()
                while self.pos < len(self.source) and self.source[self.pos] != '}':
                    self._advance()
                if self.pos < len(self.source):
                    self._advance()
            elif (ch == '(' and self.pos + 1 < len(self.source)
                  and self.source[self.pos + 1] == '*'):
                self._advance()
                self._advance()
                while self.pos + 1 < len(self.source):
                    if (self.source[self.pos] == '*'
                            and self.source[self.pos + 1] == ')'):
                        self._advance()
                        self._advance()
                        break
                    self._advance()
            elif (ch == '/' and self.pos + 1 < len(self.source)
                  and self.source[self.pos + 1] == '/'):
                while self.pos < len(self.source) and self.source[self.pos] != '\n':
                    self._advance()
            else:
                break

    def _read_string(self) -> str:
        self._advance()  # skip opening '
        chars: list[str] = []
        while self.pos < len(self.source):
            ch = self.source[self.pos]
            if ch == "'":
                if (self.pos + 1 < len(self.source)
                        and self.source[self.pos + 1] == "'"):
                    chars.append("'")
                    self._advance()
                    self._advance()
                else:
                    self._advance()
                    return ''.join(chars)
            elif ch == '\n':
                self._error("unterminated string literal")
            else:
                chars.append(ch)
                self._advance()
        self._error("unterminated string literal")

    def _read_identifier(self) -> str:
        start = self.pos
        while (self.pos < len(self.source)
               and (self.source[self.pos].isalnum() or self.source[self.pos] == '_')):
            self._advance()
        return self.source[start:self.pos]

    def tokenize(self) -> List[Token]:
        tokens: list[Token] = []
        while True:
            self._skip_whitespace_and_comments()
            if self.pos >= len(self.source):
                tokens.append(Token(TokenType.EOF, '', self.line, self.col))
                break

            ch = self.source[self.pos]
            line, col = self.line, self.col

            if ch == "'":
                tokens.append(Token(TokenType.STRING_LITERAL,
                                    self._read_string(), line, col))
            elif ch.isalpha() or ch == '_':
                word = self._read_identifier()
                ttype = KEYWORDS.get(word.lower(), TokenType.IDENTIFIER)
                tokens.append(Token(ttype, word, line, col))
            elif ch == ';':
                tokens.append(Token(TokenType.SEMICOLON, ';', line, col))
                self._advance()
            elif ch == '.':
                tokens.append(Token(TokenType.DOT, '.', line, col))
                self._advance()
            elif ch == '(':
                tokens.append(Token(TokenType.LPAREN, '(', line, col))
                self._advance()
            elif ch == ')':
                tokens.append(Token(TokenType.RPAREN, ')', line, col))
                self._advance()
            else:
                self._error(f"unexpected character: '{ch}'")

        return tokens

# ── AST ─────────────────────────────────────────────────────

@dataclass
class WritelnStmt:
    arg: Optional[str]  # string literal, or None for bare writeln

@dataclass
class WriteStmt:
    arg: str

@dataclass
class PascalProgram:
    name: str
    statements: list

# ── Parser ──────────────────────────────────────────────────

class Parser:
    def __init__(self, tokens: List[Token]):
        self.tokens = tokens
        self.pos = 0

    def _error(self, msg: str):
        tok = self._current()
        raise SyntaxError(f"line {tok.line}, col {tok.col}: {msg}")

    def _current(self) -> Token:
        return self.tokens[self.pos]

    def _expect(self, ttype: TokenType) -> Token:
        tok = self._current()
        if tok.type != ttype:
            self._error(f"expected {ttype.name}, got {tok.type.name} ('{tok.value}')")
        self.pos += 1
        return tok

    def parse(self) -> PascalProgram:
        self._expect(TokenType.PROGRAM)
        name = self._expect(TokenType.IDENTIFIER).value
        self._expect(TokenType.SEMICOLON)
        self._expect(TokenType.BEGIN)
        stmts = self._parse_statement_list()
        self._expect(TokenType.END)
        self._expect(TokenType.DOT)
        return PascalProgram(name=name, statements=stmts)

    def _parse_statement_list(self) -> list:
        stmts: list = []
        while self._current().type not in (TokenType.END, TokenType.EOF):
            stmt = self._parse_statement()
            if stmt is not None:
                stmts.append(stmt)
            if self._current().type == TokenType.SEMICOLON:
                self.pos += 1
        return stmts

    def _parse_statement(self):
        tok = self._current()
        if tok.type == TokenType.WRITELN:
            return self._parse_writeln()
        if tok.type == TokenType.WRITE:
            return self._parse_write()
        if tok.type in (TokenType.SEMICOLON, TokenType.END):
            return None
        self._error(f"unexpected token: {tok.type.name} ('{tok.value}')")

    def _parse_writeln(self) -> WritelnStmt:
        self._expect(TokenType.WRITELN)
        arg = None
        if self._current().type == TokenType.LPAREN:
            self._expect(TokenType.LPAREN)
            arg = self._expect(TokenType.STRING_LITERAL).value
            self._expect(TokenType.RPAREN)
        return WritelnStmt(arg=arg)

    def _parse_write(self) -> WriteStmt:
        self._expect(TokenType.WRITE)
        self._expect(TokenType.LPAREN)
        arg = self._expect(TokenType.STRING_LITERAL).value
        self._expect(TokenType.RPAREN)
        return WriteStmt(arg=arg)

# ── Code generator ──────────────────────────────────────────

class CodeGenerator:
    def __init__(self, base_address: int = 0x8400):
        self.base = base_address
        self.code = bytearray()
        self.strings: List[str] = []
        self._fixups: List[tuple[int, int]] = []  # (code_offset, string_index)

    def _add_string(self, s: str) -> int:
        if s in self.strings:
            return self.strings.index(s)
        self.strings.append(s)
        return len(self.strings) - 1

    def _emit_lit16_fixup(self, string_index: int):
        self.code.append(OP_LIT16)
        self._fixups.append((len(self.code), string_index))
        self.code.extend([0x00, 0x00])

    def _emit_csp(self, proc: int):
        self.code.append(OP_CSP)
        self.code.append(proc)

    def _build_native_stub(self, pcode_addr: int) -> bytes:
        """Build the native Otto stub that bootstraps the P-Machine."""
        stub = bytearray()
        stub.extend([0xA5, (pcode_addr >> 8) & 0xFF])        # LDD #msb
        stub.extend([0xA6, pcode_addr & 0xFF])                # LDE #lsb
        stub.extend([0x20,                                     # JSR zero-page
                      (PMACHINE_ADDR >> 8) & 0xFF,             #   addr MSB
                      PMACHINE_ADDR & 0xFF,                    #   addr LSB
                      0x00])                                   #   pad byte
        stub.append(0x60)                                      # RTS
        return bytes(stub)

    def generate(self, program: PascalProgram) -> bytes:
        for stmt in program.statements:
            if isinstance(stmt, WritelnStmt):
                if stmt.arg is not None:
                    idx = self._add_string(stmt.arg)
                    self._emit_lit16_fixup(idx)
                    self._emit_csp(CSP_WRITELN)
                else:
                    self._emit_csp(CSP_WRITELN_NOARG)
            elif isinstance(stmt, WriteStmt):
                idx = self._add_string(stmt.arg)
                self._emit_lit16_fixup(idx)
                self._emit_csp(CSP_WRITE)

        self.code.append(OP_HALT)

        # Layout:  [native_stub | pcode_header | code | data]
        pcode_base = self.base + NATIVE_STUB_SIZE
        code_offset = PCODE_HEADER_SIZE
        data_offset = PCODE_HEADER_SIZE + len(self.code)

        # Calculate byte offset of each string inside the data section
        str_offsets: list[int] = []
        off = 0
        for s in self.strings:
            str_offsets.append(off)
            off += len(s.encode('ascii')) + 1

        # Patch LIT16 placeholders with absolute RAM addresses
        for code_pos, sidx in self._fixups:
            addr = pcode_base + data_offset + str_offsets[sidx]
            self.code[code_pos]     = addr & 0xFF
            self.code[code_pos + 1] = (addr >> 8) & 0xFF

        # Build data section
        data = bytearray()
        for s in self.strings:
            data.extend(s.encode('ascii'))
            data.append(0x00)

        # Assemble P-code header
        header = bytearray(MAGIC)
        header.append(FORMAT_VERSION)
        header.append(code_offset & 0xFF)
        header.append((code_offset >> 8) & 0xFF)
        header.append(data_offset & 0xFF)
        header.append((data_offset >> 8) & 0xFF)

        # Prepend native stub
        stub = self._build_native_stub(pcode_base)

        return bytes(stub) + bytes(header + self.code + data)

# ── Public API ──────────────────────────────────────────────

def compile_pascal(source: str, base_address: int = 0x8400) -> bytes:
    tokens = Lexer(source).tokenize()
    program = Parser(tokens).parse()
    return CodeGenerator(base_address).generate(program)

# ── CLI ─────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description="Tiny Pascal compiler for the Otto P-Machine")
    ap.add_argument("source", help="Pascal source file (.pas)")
    ap.add_argument("-o", "--output", required=True,
                    help="Output P-code binary file")
    ap.add_argument("--base", type=lambda x: int(x, 0), default=0x8400,
                    help="Base RAM address (default: 0x8400)")
    args = ap.parse_args()

    with open(args.source, 'r') as f:
        source = f.read()

    try:
        binary = compile_pascal(source, args.base)
    except SyntaxError as e:
        print(f"Compilation error: {e}", file=sys.stderr)
        sys.exit(1)

    with open(args.output, 'wb') as f:
        f.write(binary)

    print(f"Compiled {args.source} -> {args.output} ({len(binary)} bytes)")


if __name__ == '__main__':
    main()
