#!/usr/bin/env python3
"""
Tiny Pascal Compiler for Project Otto P-Machine.

Compiles a minimal subset of Pascal into P-code bytecode
that runs on the Otto P-Machine interpreter (ROM #3).

Supported (MS2): program structure, var declarations (integer),
assignments, arithmetic expressions (+, -, *, div, mod, unary -),
writeln/write with string literals or integer expressions.

Usage:
    python pascal_compiler.py input.pas -o output.bin [--base 0x8400]
"""

import sys
import argparse
from enum import Enum, auto
from dataclasses import dataclass, field
from typing import List, Optional, Union

# ── P-code constants ────────────────────────────────────────

OP_HALT  = 0x00
OP_LIT   = 0x01
OP_LIT16 = 0x02
OP_LOAD  = 0x03
OP_STORE = 0x04
OP_ADD   = 0x05
OP_SUB   = 0x06
OP_MUL   = 0x07
OP_DIV   = 0x08
OP_NEG   = 0x09
OP_MOD   = 0x0A
OP_CSP   = 0x10

CSP_WRITE         = 0x00
CSP_WRITELN       = 0x01
CSP_WRITELN_NOARG = 0x02
CSP_WRITE_INT     = 0x03
CSP_WRITELN_INT   = 0x04

MAGIC = bytes([0x50, 0x4D])   # "PM"
FORMAT_VERSION = 0x01
PCODE_HEADER_SIZE = 7

NATIVE_STUB_SIZE = 9
PMACHINE_ADDR = 0x4000

# ── Token types ─────────────────────────────────────────────

class TokenType(Enum):
    PROGRAM        = auto()
    BEGIN          = auto()
    END            = auto()
    VAR            = auto()
    INTEGER        = auto()
    DIV            = auto()
    MOD            = auto()
    WRITELN        = auto()
    WRITE          = auto()
    IDENTIFIER     = auto()
    STRING_LITERAL = auto()
    NUMBER         = auto()
    ASSIGN         = auto()   # :=
    COLON          = auto()   # :
    COMMA          = auto()   # ,
    SEMICOLON      = auto()   # ;
    DOT            = auto()   # .
    LPAREN         = auto()   # (
    RPAREN         = auto()   # )
    PLUS           = auto()   # +
    MINUS          = auto()   # -
    STAR           = auto()   # *
    EOF            = auto()

KEYWORDS = {
    'program': TokenType.PROGRAM,
    'begin':   TokenType.BEGIN,
    'end':     TokenType.END,
    'var':     TokenType.VAR,
    'integer': TokenType.INTEGER,
    'div':     TokenType.DIV,
    'mod':     TokenType.MOD,
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

    def _peek(self, offset: int = 0) -> str:
        p = self.pos + offset
        return self.source[p] if p < len(self.source) else '\0'

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
            elif ch == '(' and self._peek(1) == '*':
                self._advance()
                self._advance()
                while self.pos + 1 < len(self.source):
                    if self.source[self.pos] == '*' and self._peek(1) == ')':
                        self._advance()
                        self._advance()
                        break
                    self._advance()
            elif ch == '/' and self._peek(1) == '/':
                while self.pos < len(self.source) and self.source[self.pos] != '\n':
                    self._advance()
            else:
                break

    def _read_string(self) -> str:
        self._advance()
        chars: list[str] = []
        while self.pos < len(self.source):
            ch = self.source[self.pos]
            if ch == "'":
                if self._peek(1) == "'":
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
        while self.pos < len(self.source) and (self.source[self.pos].isalnum() or self.source[self.pos] == '_'):
            self._advance()
        return self.source[start:self.pos]

    def _read_number(self) -> str:
        start = self.pos
        while self.pos < len(self.source) and self.source[self.pos].isdigit():
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
                tokens.append(Token(TokenType.STRING_LITERAL, self._read_string(), line, col))
            elif ch.isdigit():
                tokens.append(Token(TokenType.NUMBER, self._read_number(), line, col))
            elif ch.isalpha() or ch == '_':
                word = self._read_identifier()
                ttype = KEYWORDS.get(word.lower(), TokenType.IDENTIFIER)
                tokens.append(Token(ttype, word, line, col))
            elif ch == ':' and self._peek(1) == '=':
                tokens.append(Token(TokenType.ASSIGN, ':=', line, col))
                self._advance()
                self._advance()
            elif ch == ':':
                tokens.append(Token(TokenType.COLON, ':', line, col))
                self._advance()
            elif ch == ',':
                tokens.append(Token(TokenType.COMMA, ',', line, col))
                self._advance()
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
            elif ch == '+':
                tokens.append(Token(TokenType.PLUS, '+', line, col))
                self._advance()
            elif ch == '-':
                tokens.append(Token(TokenType.MINUS, '-', line, col))
                self._advance()
            elif ch == '*':
                tokens.append(Token(TokenType.STAR, '*', line, col))
                self._advance()
            else:
                self._error(f"unexpected character: '{ch}'")

        return tokens

# ── AST ─────────────────────────────────────────────────────

@dataclass
class NumberLiteral:
    value: int

@dataclass
class StringLiteral:
    value: str

@dataclass
class VarRef:
    name: str

@dataclass
class BinaryOp:
    op: str
    left: 'Expression'
    right: 'Expression'

@dataclass
class UnaryOp:
    op: str
    operand: 'Expression'

Expression = Union[NumberLiteral, StringLiteral, VarRef, BinaryOp, UnaryOp]

@dataclass
class VarDecl:
    names: List[str]

@dataclass
class AssignStmt:
    target: str
    expr: Expression

@dataclass
class WritelnStmt:
    arg: Optional[Expression]

@dataclass
class WriteStmt:
    arg: Expression

Statement = Union[VarDecl, AssignStmt, WritelnStmt, WriteStmt]

@dataclass
class PascalProgram:
    name: str
    var_decls: List[VarDecl]
    statements: List[Statement]

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

        var_decls: list[VarDecl] = []
        if self._current().type == TokenType.VAR:
            var_decls = self._parse_var_block()

        self._expect(TokenType.BEGIN)
        stmts = self._parse_statement_list()
        self._expect(TokenType.END)
        self._expect(TokenType.DOT)
        return PascalProgram(name=name, var_decls=var_decls, statements=stmts)

    def _parse_var_block(self) -> list[VarDecl]:
        self._expect(TokenType.VAR)
        decls: list[VarDecl] = []
        while self._current().type == TokenType.IDENTIFIER:
            names = [self._expect(TokenType.IDENTIFIER).value]
            while self._current().type == TokenType.COMMA:
                self.pos += 1
                names.append(self._expect(TokenType.IDENTIFIER).value)
            self._expect(TokenType.COLON)
            self._expect(TokenType.INTEGER)
            self._expect(TokenType.SEMICOLON)
            decls.append(VarDecl(names=names))
        return decls

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
        if tok.type == TokenType.IDENTIFIER:
            return self._parse_assignment()
        if tok.type in (TokenType.SEMICOLON, TokenType.END):
            return None
        self._error(f"unexpected token: {tok.type.name} ('{tok.value}')")

    def _parse_assignment(self) -> AssignStmt:
        name = self._expect(TokenType.IDENTIFIER).value
        self._expect(TokenType.ASSIGN)
        expr = self._parse_expression()
        return AssignStmt(target=name, expr=expr)

    def _parse_writeln(self) -> WritelnStmt:
        self._expect(TokenType.WRITELN)
        if self._current().type == TokenType.LPAREN:
            self._expect(TokenType.LPAREN)
            expr = self._parse_expression()
            self._expect(TokenType.RPAREN)
            return WritelnStmt(arg=expr)
        return WritelnStmt(arg=None)

    def _parse_write(self) -> WriteStmt:
        self._expect(TokenType.WRITE)
        self._expect(TokenType.LPAREN)
        expr = self._parse_expression()
        self._expect(TokenType.RPAREN)
        return WriteStmt(arg=expr)

    # ── Expression parsing (recursive descent with precedence) ──

    def _parse_expression(self) -> Expression:
        left = self._parse_term()
        while self._current().type in (TokenType.PLUS, TokenType.MINUS):
            op = self._current().value
            self.pos += 1
            right = self._parse_term()
            left = BinaryOp(op=op, left=left, right=right)
        return left

    def _parse_term(self) -> Expression:
        left = self._parse_factor()
        while self._current().type in (TokenType.STAR, TokenType.DIV, TokenType.MOD):
            op = self._current().value.lower()
            if op == '*':
                pass
            self.pos += 1
            right = self._parse_factor()
            left = BinaryOp(op=op, left=left, right=right)
        return left

    def _parse_factor(self) -> Expression:
        tok = self._current()

        if tok.type == TokenType.NUMBER:
            self.pos += 1
            value = int(tok.value)
            if value > 32767:
                self._error(f"integer literal {value} exceeds 16-bit signed range")
            return NumberLiteral(value=value)

        if tok.type == TokenType.STRING_LITERAL:
            self.pos += 1
            return StringLiteral(value=tok.value)

        if tok.type == TokenType.IDENTIFIER:
            self.pos += 1
            return VarRef(name=tok.value)

        if tok.type == TokenType.LPAREN:
            self.pos += 1
            expr = self._parse_expression()
            self._expect(TokenType.RPAREN)
            return expr

        if tok.type == TokenType.MINUS:
            self.pos += 1
            operand = self._parse_factor()
            if isinstance(operand, NumberLiteral):
                return NumberLiteral(value=-operand.value)
            return UnaryOp(op='-', operand=operand)

        self._error(f"expected expression, got {tok.type.name} ('{tok.value}')")

# ── Code generator ──────────────────────────────────────────

class CodeGenerator:
    def __init__(self, base_address: int = 0x8400):
        self.base = base_address
        self.code = bytearray()
        self.strings: List[str] = []
        self._fixups: List[tuple[int, int]] = []
        self.symbols: dict[str, int] = {}
        self._next_var_offset = 0

    def _add_string(self, s: str) -> int:
        if s in self.strings:
            return self.strings.index(s)
        self.strings.append(s)
        return len(self.strings) - 1

    def _emit(self, *args: int):
        for b in args:
            self.code.append(b & 0xFF)

    def _emit_lit16(self, value: int):
        self.code.append(OP_LIT16)
        self.code.append(value & 0xFF)
        self.code.append((value >> 8) & 0xFF)

    def _emit_lit16_fixup(self, string_index: int):
        self.code.append(OP_LIT16)
        self._fixups.append((len(self.code), string_index))
        self.code.extend([0x00, 0x00])

    def _emit_csp(self, proc: int):
        self._emit(OP_CSP, proc)

    def _register_vars(self, var_decls: List[VarDecl]):
        for decl in var_decls:
            for name in decl.names:
                lower = name.lower()
                if lower in self.symbols:
                    raise SyntaxError(f"duplicate variable declaration: '{name}'")
                self.symbols[lower] = self._next_var_offset
                self._next_var_offset += 2

    def _var_offset(self, name: str) -> int:
        lower = name.lower()
        if lower not in self.symbols:
            raise SyntaxError(f"undefined variable: '{name}'")
        return self.symbols[lower]

    def _gen_expr(self, expr: Expression):
        if isinstance(expr, NumberLiteral):
            self._emit_lit16(expr.value & 0xFFFF)
        elif isinstance(expr, StringLiteral):
            idx = self._add_string(expr.value)
            self._emit_lit16_fixup(idx)
        elif isinstance(expr, VarRef):
            self._emit(OP_LOAD, self._var_offset(expr.name))
        elif isinstance(expr, UnaryOp):
            self._gen_expr(expr.operand)
            if expr.op == '-':
                self._emit(OP_NEG)
        elif isinstance(expr, BinaryOp):
            self._gen_expr(expr.left)
            self._gen_expr(expr.right)
            op_map = {'+': OP_ADD, '-': OP_SUB, '*': OP_MUL, 'div': OP_DIV, 'mod': OP_MOD}
            self._emit(op_map[expr.op])

    def _is_string_expr(self, expr: Expression) -> bool:
        return isinstance(expr, StringLiteral)

    def _gen_stmt(self, stmt: Statement):
        if isinstance(stmt, AssignStmt):
            self._gen_expr(stmt.expr)
            self._emit(OP_STORE, self._var_offset(stmt.target))
        elif isinstance(stmt, WritelnStmt):
            if stmt.arg is None:
                self._emit_csp(CSP_WRITELN_NOARG)
            elif self._is_string_expr(stmt.arg):
                self._gen_expr(stmt.arg)
                self._emit_csp(CSP_WRITELN)
            else:
                self._gen_expr(stmt.arg)
                self._emit_csp(CSP_WRITELN_INT)
        elif isinstance(stmt, WriteStmt):
            if self._is_string_expr(stmt.arg):
                self._gen_expr(stmt.arg)
                self._emit_csp(CSP_WRITE)
            else:
                self._gen_expr(stmt.arg)
                self._emit_csp(CSP_WRITE_INT)

    def _build_native_stub(self, pcode_addr: int) -> bytes:
        stub = bytearray()
        stub.extend([0xA5, (pcode_addr >> 8) & 0xFF])
        stub.extend([0xA6, pcode_addr & 0xFF])
        stub.extend([0x20,
                      (PMACHINE_ADDR >> 8) & 0xFF,
                      PMACHINE_ADDR & 0xFF,
                      0x00])
        stub.append(0x60)
        return bytes(stub)

    def generate(self, program: PascalProgram) -> bytes:
        self._register_vars(program.var_decls)

        for stmt in program.statements:
            self._gen_stmt(stmt)

        self.code.append(OP_HALT)

        pcode_base = self.base + NATIVE_STUB_SIZE
        code_offset = PCODE_HEADER_SIZE
        data_offset = PCODE_HEADER_SIZE + len(self.code)

        str_offsets: list[int] = []
        off = 0
        for s in self.strings:
            str_offsets.append(off)
            off += len(s.encode('ascii')) + 1

        for code_pos, sidx in self._fixups:
            addr = pcode_base + data_offset + str_offsets[sidx]
            self.code[code_pos]     = addr & 0xFF
            self.code[code_pos + 1] = (addr >> 8) & 0xFF

        data = bytearray()
        for s in self.strings:
            data.extend(s.encode('ascii'))
            data.append(0x00)

        header = bytearray(MAGIC)
        header.append(FORMAT_VERSION)
        header.append(code_offset & 0xFF)
        header.append((code_offset >> 8) & 0xFF)
        header.append(data_offset & 0xFF)
        header.append((data_offset >> 8) & 0xFF)

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
