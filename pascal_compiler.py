#!/usr/bin/env python3
"""
Tiny Pascal Compiler for Project Otto P-Machine.

Compiles a minimal subset of Pascal into P-code bytecode
that runs on the Otto P-Machine interpreter.

Supported (MS4.5): program structure, var declarations (integer, arrays),
assignments, arithmetic expressions (+, -, *, div, mod, unary -),
writeln/write with string literals or integer expressions,
readln for integer input,
control flow (if/then/else, while/do, for/to/downto),
relational operators (=, <>, <, >, <=, >=),
boolean operators (and, or, not), compound statements (begin..end),
procedures and functions (nested, recursive), parameter passing (by value),
one-dimensional arrays of integer with compile-time constant bounds.

Usage:
    python pascal_compiler.py input.pas -o output.bin [--base 0x8400]
"""

import sys
import os
import re
import struct
import argparse
from enum import Enum, auto
from dataclasses import dataclass, field
from typing import List, Optional, Union

# ── P-code constants ────────────────────────────────────────

OP_HALT    = 0x00
OP_LIT     = 0x01
OP_LIT16   = 0x02
OP_LOAD    = 0x03
OP_STORE   = 0x04
OP_ADD     = 0x05
OP_SUB     = 0x06
OP_MUL     = 0x07
OP_DIV     = 0x08
OP_NEG     = 0x09
OP_MOD     = 0x0A
OP_JMP     = 0x0B
OP_JPC     = 0x0C
OP_EQ      = 0x0D
OP_NE      = 0x0E
OP_LT      = 0x0F
OP_CSP     = 0x10
OP_GE      = 0x11
OP_GT      = 0x12
OP_LE      = 0x13
OP_AND     = 0x14
OP_OR      = 0x15
OP_NOT     = 0x16
OP_CALL    = 0x17
OP_ENTER   = 0x18
OP_RET     = 0x19
OP_LOAD_L  = 0x1A
OP_STORE_L = 0x1B
OP_LOAD_A  = 0x1C
OP_STORE_A = 0x1D
OP_LOAD_AL = 0x1E
OP_STORE_AL= 0x1F
OP_ABS     = 0x20
OP_LOAD_REF  = 0x21
OP_STORE_REF = 0x22
OP_PUSH_ADDR = 0x23
OP_PUSH_ADDR_L = 0x24
OP_ENTER16 = 0x25
OP_LOADW   = 0x26
OP_STOREW  = 0x27
OP_FLIT      = 0x30
OP_FLOAD     = 0x31
OP_FSTORE    = 0x32
OP_FADD      = 0x33
OP_FSUB      = 0x34
OP_FMUL      = 0x35
OP_FDIV      = 0x36
OP_FNEG      = 0x37
OP_ITOF      = 0x38
OP_FTOI      = 0x39
OP_FCMP      = 0x3A
OP_FLOAD_L   = 0x3B
OP_FSTORE_L  = 0x3C
OP_FABS      = 0x3D

CSP_WRITE         = 0x00
CSP_WRITELN       = 0x01
CSP_WRITELN_NOARG = 0x02
CSP_WRITE_INT     = 0x03
CSP_WRITELN_INT   = 0x04
CSP_READLN_INT    = 0x05
CSP_WRITE_CHAR    = 0x06
CSP_WRITE_REAL    = 0x07
CSP_WRITELN_REAL  = 0x08
CSP_READLN_REAL   = 0x09
CSP_RANDOM        = 0x0A
CSP_PEEK          = 0x0B
CSP_POKE          = 0x0C
CSP_VT100         = 0x0D
CSP_WAIT_MS       = 0x0E
CSP_READLN_STR    = 0x0F
CSP_WRITE_STR     = 0x10
CSP_WRITELN_STR   = 0x11
CSP_STR_EQ        = 0x12
CSP_STR_ASSIGN_LIT = 0x13
CSP_STR_COPY      = 0x14
CSP_LENGTH        = 0x15

STRING_SIZE = 81   # len byte + 80 chars
FRAME_MAX = 512

MAGIC = bytes([0x50, 0x4D])   # "PM"
FORMAT_VERSION = 0x01
PCODE_HEADER_SIZE = 7

NATIVE_STUB_SIZE = 9
OT_HEADER_SIZE = 6           # magic(2) + version(1) + address(3)
PMACHINE_ADDR_DEFAULT = 0x4000

def _read_pmachine_addr() -> int:
    symbols_path = os.path.join(os.path.dirname(__file__) or '.', 'kernel', 'symbols.asm')
    try:
        with open(symbols_path, 'r') as f:
            for line in f:
                m = re.match(r'#const\s+PM_ENTRY\s*=\s*(0x[0-9A-Fa-f]+)', line)
                if m:
                    return int(m.group(1), 16)
    except FileNotFoundError:
        pass
    return PMACHINE_ADDR_DEFAULT

PMACHINE_ADDR = _read_pmachine_addr()

# ── Token types ─────────────────────────────────────────────

class TokenType(Enum):
    PROGRAM        = auto()
    BEGIN          = auto()
    END            = auto()
    CONST          = auto()
    VAR            = auto()
    INTEGER        = auto()
    REAL           = auto()
    DIV            = auto()
    MOD            = auto()
    WRITELN        = auto()
    WRITE          = auto()
    READLN         = auto()
    IF             = auto()
    THEN           = auto()
    ELSE           = auto()
    WHILE          = auto()
    DO             = auto()
    FOR            = auto()
    TO             = auto()
    DOWNTO         = auto()
    AND            = auto()
    OR             = auto()
    NOT            = auto()
    PROCEDURE      = auto()
    FUNCTION       = auto()
    REPEAT         = auto()
    UNTIL          = auto()
    CHR            = auto()
    ORD            = auto()
    ABS            = auto()
    ODD            = auto()
    RANDOM         = auto()
    PEEK           = auto()
    POKE           = auto()
    STRING         = auto()
    LENGTH         = auto()
    ARRAY          = auto()
    OF             = auto()
    IDENTIFIER     = auto()
    STRING_LITERAL = auto()
    NUMBER         = auto()
    FLOAT_LITERAL  = auto()
    ASSIGN         = auto()   # :=
    COLON          = auto()   # :
    COMMA          = auto()   # ,
    SEMICOLON      = auto()   # ;
    DOT            = auto()   # .
    DOTDOT         = auto()   # ..
    LBRACKET       = auto()   # [
    RBRACKET       = auto()   # ]
    LPAREN         = auto()   # (
    RPAREN         = auto()   # )
    PLUS           = auto()   # +
    MINUS          = auto()   # -
    STAR           = auto()   # *
    SLASH          = auto()   # /
    EQ             = auto()   # =
    NE             = auto()   # <>
    LT             = auto()   # <
    GT             = auto()   # >
    LE             = auto()   # <=
    GE             = auto()   # >=
    EOF            = auto()

KEYWORDS = {
    'program':   TokenType.PROGRAM,
    'begin':     TokenType.BEGIN,
    'end':       TokenType.END,
    'const':     TokenType.CONST,
    'var':       TokenType.VAR,
    'integer':   TokenType.INTEGER,
    'real':      TokenType.REAL,
    'div':       TokenType.DIV,
    'mod':       TokenType.MOD,
    'writeln':   TokenType.WRITELN,
    'write':     TokenType.WRITE,
    'readln':    TokenType.READLN,
    'if':        TokenType.IF,
    'then':      TokenType.THEN,
    'else':      TokenType.ELSE,
    'while':     TokenType.WHILE,
    'do':        TokenType.DO,
    'for':       TokenType.FOR,
    'to':        TokenType.TO,
    'downto':    TokenType.DOWNTO,
    'and':       TokenType.AND,
    'or':        TokenType.OR,
    'not':       TokenType.NOT,
    'procedure': TokenType.PROCEDURE,
    'function':  TokenType.FUNCTION,
    'repeat':    TokenType.REPEAT,
    'until':     TokenType.UNTIL,
    'chr':       TokenType.CHR,
    'ord':       TokenType.ORD,
    'abs':       TokenType.ABS,
    'odd':       TokenType.ODD,
    'random':    TokenType.RANDOM,
    'peek':      TokenType.PEEK,
    'poke':      TokenType.POKE,
    'string':    TokenType.STRING,
    'length':    TokenType.LENGTH,
    'array':     TokenType.ARRAY,
    'of':        TokenType.OF,
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

    def _read_number(self) -> tuple[str, bool]:
        """Returns (number_string, is_float)."""
        start = self.pos
        while self.pos < len(self.source) and self.source[self.pos].isdigit():
            self._advance()
        if (self.pos < len(self.source) and self.source[self.pos] == '.'
                and self.pos + 1 < len(self.source) and self.source[self.pos + 1] != '.'):
            self._advance()
            while self.pos < len(self.source) and self.source[self.pos].isdigit():
                self._advance()
            return self.source[start:self.pos], True
        return self.source[start:self.pos], False

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
            elif ch == '$':
                self._advance()
                start = self.pos
                while self.pos < len(self.source) and self.source[self.pos] in '0123456789abcdefABCDEF':
                    self._advance()
                if self.pos == start:
                    self._error("expected hex digit after '$'")
                tokens.append(Token(TokenType.NUMBER, str(int(self.source[start:self.pos], 16)), line, col))
            elif ch.isdigit():
                num_str, is_float = self._read_number()
                if is_float:
                    tokens.append(Token(TokenType.FLOAT_LITERAL, num_str, line, col))
                else:
                    tokens.append(Token(TokenType.NUMBER, num_str, line, col))
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
                if self._peek(1) == '.':
                    tokens.append(Token(TokenType.DOTDOT, '..', line, col))
                    self._advance()
                    self._advance()
                else:
                    tokens.append(Token(TokenType.DOT, '.', line, col))
                    self._advance()
            elif ch == '[':
                tokens.append(Token(TokenType.LBRACKET, '[', line, col))
                self._advance()
            elif ch == ']':
                tokens.append(Token(TokenType.RBRACKET, ']', line, col))
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
            elif ch == '/' and self._peek(1) != '/':
                tokens.append(Token(TokenType.SLASH, '/', line, col))
                self._advance()
            elif ch == '=':
                tokens.append(Token(TokenType.EQ, '=', line, col))
                self._advance()
            elif ch == '<':
                if self._peek(1) == '>':
                    tokens.append(Token(TokenType.NE, '<>', line, col))
                    self._advance()
                    self._advance()
                elif self._peek(1) == '=':
                    tokens.append(Token(TokenType.LE, '<=', line, col))
                    self._advance()
                    self._advance()
                else:
                    tokens.append(Token(TokenType.LT, '<', line, col))
                    self._advance()
            elif ch == '>':
                if self._peek(1) == '=':
                    tokens.append(Token(TokenType.GE, '>=', line, col))
                    self._advance()
                    self._advance()
                else:
                    tokens.append(Token(TokenType.GT, '>', line, col))
                    self._advance()
            else:
                self._error(f"unexpected character: '{ch}'")

        return tokens

# ── AST ─────────────────────────────────────────────────────

@dataclass
class NumberLiteral:
    value: int

@dataclass
class FloatLiteral:
    value: float

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

@dataclass
class CallExpr:
    name: str
    args: List['Expression']

@dataclass
class ArrayRef:
    name: str
    index: 'Expression'

@dataclass
class ChrExpr:
    arg: 'Expression'

@dataclass
class AbsExpr:
    arg: 'Expression'

@dataclass
class OddExpr:
    arg: 'Expression'

@dataclass
class RandomExpr:
    pass

@dataclass
class PeekExpr:
    page: 'Expression'
    addr: 'Expression'

@dataclass
class LengthExpr:
    name: str

Expression = Union[NumberLiteral, FloatLiteral, StringLiteral, VarRef, BinaryOp, UnaryOp, CallExpr, ArrayRef, ChrExpr, AbsExpr, OddExpr, RandomExpr, PeekExpr, LengthExpr]

@dataclass
class ConstDecl:
    name: str
    value: int

@dataclass
class VarDecl:
    names: List[str]
    var_type: str = 'integer'

@dataclass
class ArrayDecl:
    name: str
    low: int
    high: int

@dataclass
class ParamDecl:
    name: str
    is_var: bool = False
    param_type: str = 'integer'

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

@dataclass
class ReadlnStmt:
    var_name: str

@dataclass
class CallStmt:
    name: str
    args: List[Expression]

@dataclass
class IfStmt:
    condition: Expression
    then_stmt: 'Statement'
    else_stmt: Optional['Statement']

@dataclass
class WhileStmt:
    condition: Expression
    body: 'Statement'

@dataclass
class ForStmt:
    var_name: str
    start: Expression
    end_expr: Expression
    direction: str
    body: 'Statement'

@dataclass
class RepeatStmt:
    statements: List['Statement']
    condition: Expression

@dataclass
class ArrayAssignStmt:
    name: str
    index: Expression
    expr: Expression

@dataclass
class PokeStmt:
    page: Expression
    addr: Expression
    value: Expression

@dataclass
class CompoundStmt:
    statements: List['Statement']

Statement = Union[VarDecl, AssignStmt, WritelnStmt, WriteStmt, ReadlnStmt,
                  CallStmt, IfStmt, WhileStmt, ForStmt, RepeatStmt,
                  CompoundStmt, ArrayAssignStmt, PokeStmt]

Declaration = Union[VarDecl, ArrayDecl]

@dataclass
class ProcDecl:
    name: str
    params: List[ParamDecl]
    const_decls: List[ConstDecl]
    var_decls: List[Declaration]
    subroutines: List[Union['ProcDecl', 'FuncDecl']]
    body: CompoundStmt

@dataclass
class FuncDecl:
    name: str
    params: List[ParamDecl]
    return_type: str
    const_decls: List[ConstDecl]
    var_decls: List[Declaration]
    subroutines: List[Union['ProcDecl', 'FuncDecl']]
    body: CompoundStmt

Subroutine = Union[ProcDecl, FuncDecl]

@dataclass
class PascalProgram:
    name: str
    const_decls: List[ConstDecl]
    var_decls: List[Declaration]
    subroutines: List[Subroutine]
    statements: List[Statement]

# ── Parser ──────────────────────────────────────────────────

class Parser:
    def __init__(self, tokens: List[Token]):
        self.tokens = tokens
        self.pos = 0
        self._const_decls: list[ConstDecl] = []

    def _error(self, msg: str):
        tok = self._current()
        raise SyntaxError(f"line {tok.line}, col {tok.col}: {msg}")

    def _current(self) -> Token:
        return self.tokens[self.pos]

    def _peek_next(self) -> Token:
        nxt = self.pos + 1
        return self.tokens[nxt] if nxt < len(self.tokens) else self.tokens[-1]

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

        const_decls: list[ConstDecl] = []
        if self._current().type == TokenType.CONST:
            const_decls = self._parse_const_block()
        self._const_decls = const_decls

        var_decls: list[VarDecl] = []
        if self._current().type == TokenType.VAR:
            var_decls = self._parse_var_block()

        subroutines = self._parse_subroutines()

        self._expect(TokenType.BEGIN)
        stmts = self._parse_statement_list()
        self._expect(TokenType.END)
        self._expect(TokenType.DOT)
        return PascalProgram(name=name, const_decls=const_decls,
                             var_decls=var_decls,
                             subroutines=subroutines, statements=stmts)

    def _parse_var_block(self) -> list[Declaration]:
        self._expect(TokenType.VAR)
        decls: list[Declaration] = []
        while self._current().type == TokenType.IDENTIFIER:
            names = [self._expect(TokenType.IDENTIFIER).value]
            while self._current().type == TokenType.COMMA:
                self.pos += 1
                names.append(self._expect(TokenType.IDENTIFIER).value)
            self._expect(TokenType.COLON)
            if self._current().type == TokenType.ARRAY:
                if len(names) > 1:
                    self._error("array declaration must have a single name")
                self._expect(TokenType.ARRAY)
                self._expect(TokenType.LBRACKET)
                low = self._parse_const_int()
                self._expect(TokenType.DOTDOT)
                high = self._parse_const_int()
                self._expect(TokenType.RBRACKET)
                self._expect(TokenType.OF)
                self._expect(TokenType.INTEGER)
                self._expect(TokenType.SEMICOLON)
                decls.append(ArrayDecl(name=names[0], low=low, high=high))
            else:
                var_type = 'integer'
                if self._current().type == TokenType.REAL:
                    var_type = 'real'
                    self.pos += 1
                elif self._current().type == TokenType.STRING:
                    var_type = 'string'
                    self.pos += 1
                else:
                    self._expect(TokenType.INTEGER)
                self._expect(TokenType.SEMICOLON)
                decls.append(VarDecl(names=names, var_type=var_type))
        return decls

    def _parse_const_block(self) -> list[ConstDecl]:
        self._expect(TokenType.CONST)
        decls: list[ConstDecl] = []
        while self._current().type == TokenType.IDENTIFIER:
            name = self._expect(TokenType.IDENTIFIER).value
            self._expect(TokenType.EQ)
            value = self._parse_const_int()
            self._expect(TokenType.SEMICOLON)
            decls.append(ConstDecl(name=name, value=value))
        return decls

    def _parse_const_int(self) -> int:
        sign = 1
        if self._current().type == TokenType.MINUS:
            sign = -1
            self.pos += 1
        if self._current().type == TokenType.NUMBER:
            tok = self._expect(TokenType.NUMBER)
            return sign * int(tok.value)
        if self._current().type == TokenType.IDENTIFIER:
            tok = self._expect(TokenType.IDENTIFIER)
            return sign * self._resolve_named_const(tok.value, tok.line, tok.col)
        self._error("expected integer constant")

    def _resolve_named_const(self, name: str, line: int, col: int) -> int:
        lower = name.lower()
        for cd in self._const_decls:
            if cd.name.lower() == lower:
                return cd.value
        raise SyntaxError(f"line {line}, col {col}: undefined constant: '{name}'")

    def _parse_subroutines(self) -> list[Subroutine]:
        subs: list[Subroutine] = []
        while self._current().type in (TokenType.PROCEDURE, TokenType.FUNCTION):
            if self._current().type == TokenType.PROCEDURE:
                subs.append(self._parse_proc_decl())
            else:
                subs.append(self._parse_func_decl())
        return subs

    def _parse_param_list(self) -> list[ParamDecl]:
        params: list[ParamDecl] = []
        if self._current().type != TokenType.LPAREN:
            return params
        self.pos += 1
        if self._current().type != TokenType.RPAREN:
            params.extend(self._parse_param_group())
            while self._current().type == TokenType.SEMICOLON:
                self.pos += 1
                params.extend(self._parse_param_group())
        self._expect(TokenType.RPAREN)
        return params

    def _parse_param_group(self) -> list[ParamDecl]:
        is_var = False
        if self._current().type == TokenType.VAR:
            is_var = True
            self.pos += 1
        names = [self._expect(TokenType.IDENTIFIER).value]
        while self._current().type == TokenType.COMMA:
            self.pos += 1
            names.append(self._expect(TokenType.IDENTIFIER).value)
        self._expect(TokenType.COLON)
        param_type = 'integer'
        if self._current().type == TokenType.REAL:
            param_type = 'real'
            self.pos += 1
        else:
            self._expect(TokenType.INTEGER)
        return [ParamDecl(name=n, is_var=is_var, param_type=param_type) for n in names]

    def _parse_proc_decl(self) -> ProcDecl:
        self._expect(TokenType.PROCEDURE)
        name = self._expect(TokenType.IDENTIFIER).value
        params = self._parse_param_list()
        self._expect(TokenType.SEMICOLON)
        const_decls: list[ConstDecl] = []
        if self._current().type == TokenType.CONST:
            const_decls = self._parse_const_block()
        var_decls: list[VarDecl] = []
        if self._current().type == TokenType.VAR:
            var_decls = self._parse_var_block()
        subroutines = self._parse_subroutines()
        self._expect(TokenType.BEGIN)
        stmts = self._parse_statement_list()
        self._expect(TokenType.END)
        self._expect(TokenType.SEMICOLON)
        return ProcDecl(name=name, params=params, const_decls=const_decls,
                        var_decls=var_decls, subroutines=subroutines,
                        body=CompoundStmt(statements=stmts))

    def _parse_func_decl(self) -> FuncDecl:
        self._expect(TokenType.FUNCTION)
        name = self._expect(TokenType.IDENTIFIER).value
        params = self._parse_param_list()
        self._expect(TokenType.COLON)
        return_type = 'integer'
        if self._current().type == TokenType.REAL:
            return_type = 'real'
            self.pos += 1
        else:
            self._expect(TokenType.INTEGER)
        self._expect(TokenType.SEMICOLON)
        const_decls: list[ConstDecl] = []
        if self._current().type == TokenType.CONST:
            const_decls = self._parse_const_block()
        var_decls: list[VarDecl] = []
        if self._current().type == TokenType.VAR:
            var_decls = self._parse_var_block()
        subroutines = self._parse_subroutines()
        self._expect(TokenType.BEGIN)
        stmts = self._parse_statement_list()
        self._expect(TokenType.END)
        self._expect(TokenType.SEMICOLON)
        return FuncDecl(name=name, params=params, return_type=return_type,
                        const_decls=const_decls, var_decls=var_decls,
                        subroutines=subroutines,
                        body=CompoundStmt(statements=stmts))

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
        if tok.type == TokenType.READLN:
            return self._parse_readln()
        if tok.type == TokenType.POKE:
            return self._parse_poke()
        if tok.type == TokenType.IDENTIFIER:
            nxt = self._peek_next()
            if nxt.type == TokenType.ASSIGN:
                return self._parse_assignment()
            if nxt.type == TokenType.LBRACKET:
                return self._parse_array_assign()
            return self._parse_call_stmt()
        if tok.type == TokenType.IF:
            return self._parse_if()
        if tok.type == TokenType.WHILE:
            return self._parse_while()
        if tok.type == TokenType.FOR:
            return self._parse_for()
        if tok.type == TokenType.REPEAT:
            return self._parse_repeat()
        if tok.type == TokenType.BEGIN:
            return self._parse_compound()
        if tok.type in (TokenType.SEMICOLON, TokenType.END):
            return None
        self._error(f"unexpected token: {tok.type.name} ('{tok.value}')")

    def _parse_assignment(self) -> AssignStmt:
        name = self._expect(TokenType.IDENTIFIER).value
        self._expect(TokenType.ASSIGN)
        expr = self._parse_expression()
        return AssignStmt(target=name, expr=expr)

    def _parse_call_stmt(self) -> CallStmt:
        name = self._expect(TokenType.IDENTIFIER).value
        args: list[Expression] = []
        if self._current().type == TokenType.LPAREN:
            self.pos += 1
            if self._current().type != TokenType.RPAREN:
                args.append(self._parse_expression())
                while self._current().type == TokenType.COMMA:
                    self.pos += 1
                    args.append(self._parse_expression())
            self._expect(TokenType.RPAREN)
        return CallStmt(name=name, args=args)

    def _parse_array_assign(self) -> ArrayAssignStmt:
        name = self._expect(TokenType.IDENTIFIER).value
        self._expect(TokenType.LBRACKET)
        index = self._parse_expression()
        self._expect(TokenType.RBRACKET)
        self._expect(TokenType.ASSIGN)
        expr = self._parse_expression()
        return ArrayAssignStmt(name=name, index=index, expr=expr)

    def _parse_readln(self) -> ReadlnStmt:
        self._expect(TokenType.READLN)
        self._expect(TokenType.LPAREN)
        var_name = self._expect(TokenType.IDENTIFIER).value
        self._expect(TokenType.RPAREN)
        return ReadlnStmt(var_name=var_name)

    def _parse_poke(self) -> PokeStmt:
        self._expect(TokenType.POKE)
        self._expect(TokenType.LPAREN)
        page = self._parse_expression()
        self._expect(TokenType.COMMA)
        addr = self._parse_expression()
        self._expect(TokenType.COMMA)
        value = self._parse_expression()
        self._expect(TokenType.RPAREN)
        return PokeStmt(page=page, addr=addr, value=value)

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

    def _parse_if(self) -> IfStmt:
        self._expect(TokenType.IF)
        condition = self._parse_expression()
        self._expect(TokenType.THEN)
        then_stmt = self._parse_statement()
        else_stmt = None
        if self._current().type == TokenType.ELSE:
            self.pos += 1
            else_stmt = self._parse_statement()
        return IfStmt(condition=condition, then_stmt=then_stmt, else_stmt=else_stmt)

    def _parse_while(self) -> WhileStmt:
        self._expect(TokenType.WHILE)
        condition = self._parse_expression()
        self._expect(TokenType.DO)
        body = self._parse_statement()
        return WhileStmt(condition=condition, body=body)

    def _parse_for(self) -> ForStmt:
        self._expect(TokenType.FOR)
        var_name = self._expect(TokenType.IDENTIFIER).value
        self._expect(TokenType.ASSIGN)
        start = self._parse_expression()
        if self._current().type == TokenType.TO:
            direction = 'to'
            self.pos += 1
        elif self._current().type == TokenType.DOWNTO:
            direction = 'downto'
            self.pos += 1
        else:
            self._error("expected 'to' or 'downto'")
        end_expr = self._parse_expression()
        self._expect(TokenType.DO)
        body = self._parse_statement()
        return ForStmt(var_name=var_name, start=start, end_expr=end_expr,
                       direction=direction, body=body)

    def _parse_repeat(self) -> RepeatStmt:
        self._expect(TokenType.REPEAT)
        stmts: list = []
        while self._current().type not in (TokenType.UNTIL, TokenType.EOF):
            stmt = self._parse_statement()
            if stmt is not None:
                stmts.append(stmt)
            if self._current().type == TokenType.SEMICOLON:
                self.pos += 1
        self._expect(TokenType.UNTIL)
        condition = self._parse_expression()
        return RepeatStmt(statements=stmts, condition=condition)

    def _parse_compound(self) -> CompoundStmt:
        self._expect(TokenType.BEGIN)
        stmts = self._parse_statement_list()
        self._expect(TokenType.END)
        return CompoundStmt(statements=stmts)

    # ── Expression parsing (standard Pascal precedence) ──────

    def _parse_expression(self) -> Expression:
        left = self._parse_simple_expression()
        rel_ops = {TokenType.EQ: '=', TokenType.NE: '<>', TokenType.LT: '<',
                   TokenType.GT: '>', TokenType.LE: '<=', TokenType.GE: '>='}
        if self._current().type in rel_ops:
            op = rel_ops[self._current().type]
            self.pos += 1
            right = self._parse_simple_expression()
            left = BinaryOp(op=op, left=left, right=right)
        return left

    def _parse_simple_expression(self) -> Expression:
        left = self._parse_term()
        while self._current().type in (TokenType.PLUS, TokenType.MINUS, TokenType.OR):
            op = self._current().value.lower()
            self.pos += 1
            right = self._parse_term()
            left = BinaryOp(op=op, left=left, right=right)
        return left

    def _parse_term(self) -> Expression:
        left = self._parse_factor()
        while self._current().type in (TokenType.STAR, TokenType.SLASH,
                                        TokenType.DIV, TokenType.MOD,
                                        TokenType.AND):
            tok = self._current()
            if tok.type == TokenType.SLASH:
                op = '/'
            else:
                op = tok.value.lower()
            self.pos += 1
            right = self._parse_factor()
            left = BinaryOp(op=op, left=left, right=right)
        return left

    def _parse_factor(self) -> Expression:
        tok = self._current()

        if tok.type == TokenType.NUMBER:
            self.pos += 1
            value = int(tok.value)
            if value > 65535:
                self._error(f"integer literal {value} exceeds 16-bit range")
            return NumberLiteral(value=value)

        if tok.type == TokenType.FLOAT_LITERAL:
            self.pos += 1
            return FloatLiteral(value=float(tok.value))

        if tok.type == TokenType.STRING_LITERAL:
            self.pos += 1
            return StringLiteral(value=tok.value)

        if tok.type == TokenType.IDENTIFIER:
            self.pos += 1
            if self._current().type == TokenType.LPAREN:
                self.pos += 1
                args: list[Expression] = []
                if self._current().type != TokenType.RPAREN:
                    args.append(self._parse_expression())
                    while self._current().type == TokenType.COMMA:
                        self.pos += 1
                        args.append(self._parse_expression())
                self._expect(TokenType.RPAREN)
                return CallExpr(name=tok.value, args=args)
            if self._current().type == TokenType.LBRACKET:
                self.pos += 1
                index = self._parse_expression()
                self._expect(TokenType.RBRACKET)
                return ArrayRef(name=tok.value, index=index)
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
            if isinstance(operand, FloatLiteral):
                return FloatLiteral(value=-operand.value)
            return UnaryOp(op='-', operand=operand)

        if tok.type == TokenType.NOT:
            self.pos += 1
            operand = self._parse_factor()
            return UnaryOp(op='not', operand=operand)

        if tok.type == TokenType.ORD:
            self.pos += 1
            self._expect(TokenType.LPAREN)
            arg = self._parse_expression()
            self._expect(TokenType.RPAREN)
            if isinstance(arg, StringLiteral) and len(arg.value) == 1:
                return NumberLiteral(value=ord(arg.value))
            return arg

        if tok.type == TokenType.CHR:
            self.pos += 1
            self._expect(TokenType.LPAREN)
            arg = self._parse_expression()
            self._expect(TokenType.RPAREN)
            return ChrExpr(arg=arg)

        if tok.type == TokenType.ABS:
            self.pos += 1
            self._expect(TokenType.LPAREN)
            arg = self._parse_expression()
            self._expect(TokenType.RPAREN)
            return AbsExpr(arg=arg)

        if tok.type == TokenType.ODD:
            self.pos += 1
            self._expect(TokenType.LPAREN)
            arg = self._parse_expression()
            self._expect(TokenType.RPAREN)
            return OddExpr(arg=arg)

        if tok.type == TokenType.PEEK:
            self.pos += 1
            self._expect(TokenType.LPAREN)
            page = self._parse_expression()
            self._expect(TokenType.COMMA)
            addr = self._parse_expression()
            self._expect(TokenType.RPAREN)
            return PeekExpr(page=page, addr=addr)

        if tok.type == TokenType.RANDOM:
            self.pos += 1
            if self._current().type == TokenType.LPAREN:
                self.pos += 1
                self._expect(TokenType.RPAREN)
            return RandomExpr()

        if tok.type == TokenType.LENGTH:
            self.pos += 1
            self._expect(TokenType.LPAREN)
            name = self._expect(TokenType.IDENTIFIER).value
            self._expect(TokenType.RPAREN)
            return LengthExpr(name=name)

        self._error(f"expected expression, got {tok.type.name} ('{tok.value}')")

# ── Scope & subroutine info ─────────────────────────────────

@dataclass
class Scope:
    level: int
    symbols: dict          # name -> offset
    var_types: dict        # name -> 'integer' or 'real'
    arrays: dict
    constants: dict
    var_params: set
    is_function: bool
    function_name: Optional[str]
    function_return_type: Optional[str]
    enclosing: Optional['Scope']
    next_offset: int

@dataclass
class SubroutineInfo:
    code_offset: int
    params: list
    param_types: list      # ['integer', 'real', ...]
    is_function: bool
    return_type: str       # 'integer', 'real', or '' for procedures
    definition_level: int
    is_var_param: list = field(default_factory=list)

# ── Code generator ──────────────────────────────────────────

class CodeGenerator:
    def __init__(self, base_address: int = 0x8400):
        self.base = base_address
        self.code = bytearray()
        self.strings: List[str] = []
        self._fixups: List[tuple[int, int]] = []
        self._scope: Optional[Scope] = None
        self._subroutines: dict[str, SubroutineInfo] = {}
        self._for_counter = 0
        self._temp_str_id = 0

    # ── Scope management ─────────────────────────────────────

    def _push_scope(self, level: int, is_function: bool,
                    function_name: Optional[str] = None,
                    function_return_type: Optional[str] = None,
                    start_offset: int = 0):
        self._scope = Scope(
            level=level, symbols={}, var_types={}, arrays={}, constants={},
            var_params=set(), is_function=is_function,
            function_name=function_name,
            function_return_type=function_return_type,
            enclosing=self._scope,
            next_offset=start_offset
        )

    def _pop_scope(self):
        self._scope = self._scope.enclosing

    def _add_const(self, name: str, value: int):
        lower = name.lower()
        if lower in self._scope.symbols or lower in self._scope.constants:
            raise SyntaxError(f"duplicate declaration: '{name}'")
        self._scope.constants[lower] = value

    def _resolve_const(self, name: str) -> Optional[int]:
        lower = name.lower()
        scope = self._scope
        while scope is not None:
            if lower in scope.constants:
                return scope.constants[lower]
            scope = scope.enclosing
        return None

    def _add_var_param(self, name: str) -> int:
        offset = self._add_var(name)
        self._scope.var_params.add(name.lower())
        return offset

    def _is_var_param(self, name: str) -> tuple[bool, int]:
        """Check if name is a var param. Returns (is_var, level_diff)."""
        lower = name.lower()
        scope = self._scope
        level_diff = 0
        while scope is not None:
            if lower in scope.symbols:
                return (lower in scope.var_params, level_diff)
            scope = scope.enclosing
            level_diff += 1
        return (False, 0)

    def _add_var(self, name: str, var_type: str = 'integer') -> int:
        lower = name.lower()
        if lower in self._scope.symbols:
            raise SyntaxError(f"duplicate variable declaration: '{name}'")
        offset = self._scope.next_offset
        self._scope.symbols[lower] = offset
        self._scope.var_types[lower] = var_type
        if var_type == 'real':
            size = 4
        elif var_type == 'string':
            size = STRING_SIZE
        else:
            size = 2
        if offset + size > FRAME_MAX:
            raise SyntaxError(
                f"variable '{name}' exceeds frame size limit ({FRAME_MAX} bytes)")
        self._scope.next_offset += size
        return offset

    def _resolve_var(self, name: str) -> tuple[int, int]:
        lower = name.lower()
        scope = self._scope
        level_diff = 0
        while scope is not None:
            if lower in scope.symbols:
                return (level_diff, scope.symbols[lower])
            scope = scope.enclosing
            level_diff += 1
        raise SyntaxError(f"undefined variable: '{name}'")

    def _resolve_var_type(self, name: str) -> str:
        lower = name.lower()
        scope = self._scope
        while scope is not None:
            if lower in scope.var_types:
                return scope.var_types[lower]
            scope = scope.enclosing
        return 'integer'

    def _add_array(self, name: str, low: int, high: int) -> int:
        lower = name.lower()
        if lower in self._scope.symbols:
            raise SyntaxError(f"duplicate variable declaration: '{name}'")
        count = high - low + 1
        if count <= 0:
            raise SyntaxError(f"invalid array bounds: [{low}..{high}]")
        byte_size = count * 2
        offset = self._scope.next_offset
        if offset + byte_size > FRAME_MAX:
            raise SyntaxError(f"array '{name}' exceeds frame size limit ({FRAME_MAX} bytes)")
        self._scope.symbols[lower] = offset
        self._scope.arrays[lower] = (low, high)
        self._scope.next_offset += byte_size
        return offset

    def _resolve_array(self, name: str) -> tuple[int, int, int, int]:
        """Returns (level_diff, base_offset, low, high)."""
        lower = name.lower()
        scope = self._scope
        level_diff = 0
        while scope is not None:
            if lower in scope.arrays:
                base_offset = scope.symbols[lower]
                low, high = scope.arrays[lower]
                return (level_diff, base_offset, low, high)
            scope = scope.enclosing
            level_diff += 1
        raise SyntaxError(f"undefined array: '{name}'")

    def _is_current_function_name(self, name: str) -> bool:
        return (self._scope is not None
                and self._scope.is_function
                and self._scope.function_name is not None
                and name.lower() == self._scope.function_name.lower())

    # ── Emit helpers ─────────────────────────────────────────

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

    def _emit_flit(self, value: float):
        self.code.append(OP_FLIT)
        fb = struct.pack('<f', value)
        self.code.extend(fb)

    def _emit_lit16_fixup(self, string_index: int):
        self.code.append(OP_LIT16)
        self._fixups.append((len(self.code), string_index))
        self.code.extend([0x00, 0x00])

    def _emit_csp(self, proc: int):
        self._emit(OP_CSP, proc)

    def _emit_load_offset(self, offset: int):
        if offset < 0 or offset > 0xFFFF:
            raise SyntaxError("invalid frame offset")
        if offset <= 0xFF:
            self._emit(OP_LOAD, offset & 0xFF)
        else:
            self._emit(OP_LOADW, offset & 0xFF, (offset >> 8) & 0xFF)

    def _emit_store_offset(self, offset: int):
        if offset < 0 or offset > 0xFFFF:
            raise SyntaxError("invalid frame offset")
        if offset <= 0xFF:
            self._emit(OP_STORE, offset & 0xFF)
        else:
            self._emit(OP_STOREW, offset & 0xFF, (offset >> 8) & 0xFF)

    def _code_pos(self) -> int:
        return len(self.code)

    def _emit_jmp(self) -> int:
        pos = self._code_pos()
        self._emit(OP_JMP, 0x00, 0x00)
        return pos

    def _emit_jpc(self) -> int:
        pos = self._code_pos()
        self._emit(OP_JPC, 0x00, 0x00)
        return pos

    def _patch_jump(self, instr_pos: int, target_code_pos: int):
        offset = PCODE_HEADER_SIZE + target_code_pos
        self.code[instr_pos + 1] = offset & 0xFF
        self.code[instr_pos + 2] = (offset >> 8) & 0xFF

    def _alloc_hidden_var(self, prefix: str) -> int:
        name = f'_{prefix}_{self._for_counter}'
        return self._add_var(name)

    # ── Variable load/store with scope resolution ────────────

    def _emit_load_var(self, name: str) -> str:
        """Load variable onto eval stack. Returns the type ('integer' or 'real')."""
        is_var, _ = self._is_var_param(name)
        level_diff, offset = self._resolve_var(name)
        vtype = self._resolve_var_type(name)
        if is_var:
            if level_diff == 0:
                self._emit(OP_LOAD_REF, offset)
            else:
                self._emit(OP_LOAD_L, level_diff, offset)
            return 'integer'
        if vtype == 'real':
            if level_diff == 0:
                self._emit(OP_FLOAD, offset)
            else:
                self._emit(OP_FLOAD_L, level_diff, offset)
            return 'real'
        if vtype == 'string':
            raise SyntaxError(
                f"string variable '{name}' cannot be used as a scalar expression")
        if level_diff == 0:
            self._emit_load_offset(offset)
        else:
            if offset > 255:
                raise SyntaxError(
                    "frame offset > 255 in nested scope not supported for integers")
            self._emit(OP_LOAD_L, level_diff, offset)
        return 'integer'

    def _emit_store_var(self, name: str, value_type: str = 'integer'):
        """Store top of eval stack to variable. value_type is the type currently on stack."""
        if self._is_current_function_name(name):
            ret_type = self._scope.function_return_type or 'integer'
            if ret_type == 'real':
                if value_type == 'integer':
                    self._emit(OP_ITOF)
                self._emit(OP_FSTORE, 2)
            else:
                if value_type == 'real':
                    self._emit(OP_FTOI)
                self._emit(OP_STORE, 2)
            return
        is_var, _ = self._is_var_param(name)
        level_diff, offset = self._resolve_var(name)
        vtype = self._resolve_var_type(name)
        if is_var:
            if value_type == 'real':
                self._emit(OP_FTOI)
            if level_diff == 0:
                self._emit(OP_STORE_REF, offset)
            else:
                self._emit(OP_STORE_L, level_diff, offset)
            return
        if vtype == 'real':
            if value_type == 'integer':
                self._emit(OP_ITOF)
            if level_diff == 0:
                self._emit(OP_FSTORE, offset)
            else:
                self._emit(OP_FSTORE_L, level_diff, offset)
        elif vtype == 'string':
            raise SyntaxError("internal: use string assignment codegen")
        else:
            if value_type == 'real':
                self._emit(OP_FTOI)
            if level_diff == 0:
                self._emit_store_offset(offset)
            else:
                if offset > 255:
                    raise SyntaxError(
                        "frame offset > 255 in nested scope not supported")
                self._emit(OP_STORE_L, level_diff, offset)

    def _coerce_to_real(self, current_type: str) -> str:
        if current_type == 'integer':
            self._emit(OP_ITOF)
            return 'real'
        return current_type

    def _coerce_to_int(self, current_type: str) -> str:
        if current_type == 'real':
            self._emit(OP_FTOI)
            return 'integer'
        return current_type

    def _emit_load_array(self, name: str):
        level_diff, base_offset, low, high = self._resolve_array(name)
        adjusted_base = (base_offset - low * 2) & 0xFF
        if level_diff == 0:
            self._emit(OP_LOAD_A, adjusted_base)
        else:
            self._emit(OP_LOAD_AL, level_diff, adjusted_base)

    def _emit_store_array(self, name: str):
        level_diff, base_offset, low, high = self._resolve_array(name)
        adjusted_base = (base_offset - low * 2) & 0xFF
        if level_diff == 0:
            self._emit(OP_STORE_A, adjusted_base)
        else:
            self._emit(OP_STORE_AL, level_diff, adjusted_base)

    # ── Expression codegen ───────────────────────────────────

    def _gen_expr(self, expr: Expression) -> str:
        """Generate code for expression. Returns type: 'integer', 'real', or 'string'."""
        if isinstance(expr, NumberLiteral):
            self._emit_lit16(expr.value & 0xFFFF)
            return 'integer'
        elif isinstance(expr, FloatLiteral):
            self._emit_flit(expr.value)
            return 'real'
        elif isinstance(expr, StringLiteral):
            idx = self._add_string(expr.value)
            self._emit_lit16_fixup(idx)
            return 'string'
        elif isinstance(expr, VarRef):
            const_val = self._resolve_const(expr.name)
            if const_val is not None:
                self._emit_lit16(const_val & 0xFFFF)
                return 'integer'
            return self._emit_load_var(expr.name)
        elif isinstance(expr, UnaryOp):
            t = self._gen_expr(expr.operand)
            if expr.op == '-':
                if t == 'real':
                    self._emit(OP_FNEG)
                else:
                    self._emit(OP_NEG)
            elif expr.op == 'not':
                if t == 'real':
                    t = self._coerce_to_int(t)
                self._emit(OP_NOT)
                t = 'integer'
            return t
        elif isinstance(expr, BinaryOp):
            return self._gen_binary_op(expr)
        elif isinstance(expr, ArrayRef):
            self._gen_expr(expr.index)
            self._emit_load_array(expr.name)
            return 'integer'
        elif isinstance(expr, ChrExpr):
            t = self._gen_expr(expr.arg)
            if t == 'real':
                self._emit(OP_FTOI)
            return 'integer'
        elif isinstance(expr, AbsExpr):
            t = self._gen_expr(expr.arg)
            if t == 'real':
                self._emit(OP_FABS)
            else:
                self._emit(OP_ABS)
            return t
        elif isinstance(expr, OddExpr):
            t = self._gen_expr(expr.arg)
            if t == 'real':
                self._emit(OP_FTOI)
            self._emit_lit16(2)
            self._emit(OP_MOD)
            return 'integer'
        elif isinstance(expr, PeekExpr):
            t = self._gen_expr(expr.page)
            if t == 'real':
                self._emit(OP_FTOI)
            t = self._gen_expr(expr.addr)
            if t == 'real':
                self._emit(OP_FTOI)
            self._emit_csp(CSP_PEEK)
            return 'integer'
        elif isinstance(expr, RandomExpr):
            self._emit_csp(CSP_RANDOM)
            return 'integer'
        elif isinstance(expr, LengthExpr):
            if self._resolve_var_type(expr.name) != 'string':
                raise SyntaxError(f"length() requires a string variable, got '{expr.name}'")
            level_diff, offset = self._resolve_var(expr.name)
            if level_diff != 0:
                raise SyntaxError("length() of outer-scope string not supported")
            self._emit(OP_CSP, CSP_LENGTH, offset & 0xFF, (offset >> 8) & 0xFF)
            return 'integer'
        elif isinstance(expr, CallExpr):
            return self._gen_call(expr.name, expr.args)
        return 'integer'

    def _expr_type(self, expr: Expression) -> str:
        """Determine expression result type without generating code."""
        if isinstance(expr, NumberLiteral):
            return 'integer'
        if isinstance(expr, FloatLiteral):
            return 'real'
        if isinstance(expr, StringLiteral):
            return 'string'
        if isinstance(expr, VarRef):
            if self._resolve_const(expr.name) is not None:
                return 'integer'
            return self._resolve_var_type(expr.name)
        if isinstance(expr, UnaryOp):
            if expr.op == 'not':
                return 'integer'
            return self._expr_type(expr.operand)
        if isinstance(expr, BinaryOp):
            lt = self._expr_type(expr.left)
            rt = self._expr_type(expr.right)
            if expr.op in ('=', '<>'):
                if lt == 'string' and rt == 'string':
                    return 'integer'
            if expr.op in ('=', '<>', '<', '>', '<=', '>=', 'and', 'or', 'div', 'mod'):
                return 'integer'
            if expr.op == '/':
                return 'real'
            if lt == 'real' or rt == 'real':
                return 'real'
            return 'integer'
        if isinstance(expr, ArrayRef):
            return 'integer'
        if isinstance(expr, ChrExpr):
            return 'integer'
        if isinstance(expr, AbsExpr):
            return self._expr_type(expr.arg)
        if isinstance(expr, OddExpr):
            return 'integer'
        if isinstance(expr, PeekExpr):
            return 'integer'
        if isinstance(expr, RandomExpr):
            return 'integer'
        if isinstance(expr, LengthExpr):
            return 'integer'
        if isinstance(expr, CallExpr):
            sub = self._subroutines.get(expr.name.lower())
            if sub:
                return sub.return_type or 'integer'
            return 'integer'
        return 'integer'

    def _alloc_temp_string(self) -> int:
        self._temp_str_id += 1
        return self._add_var(f'_strtmp{self._temp_str_id}', 'string')

    def _emit_str_assign_lit(self, frame_offset: int, str_index: int):
        self._emit(OP_CSP, CSP_STR_ASSIGN_LIT)
        self._emit(frame_offset & 0xFF, (frame_offset >> 8) & 0xFF)
        self._fixups.append((len(self.code), str_index))
        self._emit(0x00, 0x00)

    def _emit_str_eq(self, off1: int, off2: int):
        self._emit(OP_CSP, CSP_STR_EQ)
        self._emit(off1 & 0xFF, (off1 >> 8) & 0xFF)
        self._emit(off2 & 0xFF, (off2 >> 8) & 0xFF)

    def _emit_str_copy(self, dst_off: int, src_off: int):
        self._emit(OP_CSP, CSP_STR_COPY)
        self._emit(dst_off & 0xFF, (dst_off >> 8) & 0xFF)
        self._emit(src_off & 0xFF, (src_off >> 8) & 0xFF)

    def _gen_string_compare(self, expr: BinaryOp) -> str:
        if expr.op not in ('=', '<>'):
            raise SyntaxError("invalid string operator")
        lo = expr.left
        ro = expr.right
        if isinstance(lo, VarRef) and isinstance(ro, VarRef):
            o1 = self._resolve_var(lo.name)[1]
            o2 = self._resolve_var(ro.name)[1]
            self._emit_str_eq(o1, o2)
        elif isinstance(lo, VarRef) and isinstance(ro, StringLiteral):
            t = self._alloc_temp_string()
            self._emit_str_assign_lit(t, self._add_string(ro.value))
            o1 = self._resolve_var(lo.name)[1]
            self._emit_str_eq(o1, t)
        elif isinstance(ro, VarRef) and isinstance(lo, StringLiteral):
            t = self._alloc_temp_string()
            self._emit_str_assign_lit(t, self._add_string(lo.value))
            o2 = self._resolve_var(ro.name)[1]
            self._emit_str_eq(t, o2)
        else:
            raise SyntaxError(
                "string comparison needs a variable on at least one side")
        if expr.op == '<>':
            self._emit(OP_NOT)
        return 'integer'

    def _gen_binary_op(self, expr: BinaryOp) -> str:
        lt_predicted = self._expr_type(expr.left)
        rt_predicted = self._expr_type(expr.right)

        if expr.op in ('=', '<>') and lt_predicted == 'string' and rt_predicted == 'string':
            return self._gen_string_compare(expr)

        # div and mod always operate on integers
        if expr.op in ('div', 'mod'):
            lt = self._gen_expr(expr.left)
            if lt == 'real':
                self._emit(OP_FTOI)
            rt = self._gen_expr(expr.right)
            if rt == 'real':
                self._emit(OP_FTOI)
            self._emit(OP_DIV if expr.op == 'div' else OP_MOD)
            return 'integer'

        # and/or always operate on integers
        if expr.op in ('and', 'or'):
            lt = self._gen_expr(expr.left)
            if lt == 'real':
                self._emit(OP_FTOI)
            rt = self._gen_expr(expr.right)
            if rt == 'real':
                self._emit(OP_FTOI)
            self._emit(OP_AND if expr.op == 'and' else OP_OR)
            return 'integer'

        use_float = False
        if expr.op in ('+', '-', '*', '/'):
            if expr.op == '/' or lt_predicted == 'real' or rt_predicted == 'real':
                use_float = True
        if expr.op in ('=', '<>', '<', '>', '<=', '>='):
            if lt_predicted == 'real' or rt_predicted == 'real':
                use_float = True

        lt = self._gen_expr(expr.left)
        if use_float and lt == 'integer':
            self._emit(OP_ITOF)
            lt = 'real'

        rt = self._gen_expr(expr.right)
        if use_float and rt == 'integer':
            self._emit(OP_ITOF)
            rt = 'real'

        if use_float:
            if expr.op in ('+', '-', '*', '/'):
                float_op_map = {'+': OP_FADD, '-': OP_FSUB, '*': OP_FMUL, '/': OP_FDIV}
                self._emit(float_op_map[expr.op])
                return 'real'
            self._emit(OP_FCMP)
            self._emit_lit16(0)
            rel_map = {'=': OP_EQ, '<>': OP_NE, '<': OP_LT,
                       '>': OP_GT, '<=': OP_LE, '>=': OP_GE}
            self._emit(rel_map[expr.op])
            return 'integer'

        if expr.op in ('+', '-', '*'):
            int_op_map = {'+': OP_ADD, '-': OP_SUB, '*': OP_MUL}
            self._emit(int_op_map[expr.op])
            return 'integer'

        if expr.op in ('=', '<>', '<', '>', '<=', '>='):
            rel_map = {'=': OP_EQ, '<>': OP_NE, '<': OP_LT,
                       '>': OP_GT, '<=': OP_LE, '>=': OP_GE}
            self._emit(rel_map[expr.op])
            return 'integer'

        raise SyntaxError(f"unknown operator: {expr.op}")

    def _is_string_expr(self, expr: Expression) -> bool:
        return isinstance(expr, StringLiteral)

    # ── Call codegen ─────────────────────────────────────────

    def _eval_const_int_expr(self, e: Expression) -> int:
        if isinstance(e, NumberLiteral):
            return e.value & 0xFFFF
        if isinstance(e, VarRef):
            c = self._resolve_const(e.name)
            if c is not None:
                return c & 0xFFFF
        raise SyntaxError("expression must be a compile-time constant integer")

    def _gen_call(self, name: str, args: list[Expression]) -> str:
        lower = name.lower()
        if lower == 'delay':
            if len(args) != 1:
                raise SyntaxError("delay expects one argument (milliseconds)")
            t = self._gen_expr(args[0])
            if t == 'real':
                self._emit(OP_FTOI)
            self._emit_csp(CSP_WAIT_MS)
            return 'integer'
        if lower == 'vt100':
            if len(args) != 1:
                raise SyntaxError("vt100 expects one argument (subcode 0..40)")
            sub = self._eval_const_int_expr(args[0])
            if sub < 0 or sub > 255:
                raise SyntaxError("vt100 subcode out of range")
            self._emit(OP_CSP, CSP_VT100, sub & 0xFF)
            return 'integer'
        if lower == 'vt100_pos':
            if len(args) != 2:
                raise SyntaxError("vt100_pos expects row, col")
            t = self._gen_expr(args[0])
            if t == 'real':
                self._emit(OP_FTOI)
            t2 = self._gen_expr(args[1])
            if t2 == 'real':
                self._emit(OP_FTOI)
            self._emit(OP_CSP, CSP_VT100, 0x02)
            return 'integer'
        if lower == 'vt100_scroll':
            if len(args) != 2:
                raise SyntaxError("vt100_scroll expects top, bottom")
            t = self._gen_expr(args[0])
            if t == 'real':
                self._emit(OP_FTOI)
            t2 = self._gen_expr(args[1])
            if t2 == 'real':
                self._emit(OP_FTOI)
            self._emit(OP_CSP, CSP_VT100, 0x20)
            return 'integer'
        sub_info = self._subroutines.get(lower)
        if sub_info is None:
            raise SyntaxError(f"undefined procedure/function: '{name}'")
        if len(args) != len(sub_info.params):
            raise SyntaxError(
                f"'{name}' expects {len(sub_info.params)} argument(s), "
                f"got {len(args)}")

        for i, arg in enumerate(args):
            if sub_info.is_var_param[i]:
                self._gen_var_arg(arg)
            else:
                t = self._gen_expr(arg)
                expected = sub_info.param_types[i]
                if expected == 'real' and t == 'integer':
                    self._emit(OP_ITOF)
                elif expected == 'integer' and t == 'real':
                    self._emit(OP_FTOI)

        caller_level = self._scope.level
        static_depth = caller_level - sub_info.definition_level

        addr = PCODE_HEADER_SIZE + sub_info.code_offset
        self._emit(OP_CALL, addr & 0xFF, (addr >> 8) & 0xFF, static_depth)
        return sub_info.return_type or 'integer'

    def _gen_var_arg(self, expr: Expression):
        """Emit code to push the address of a variable for var parameter passing."""
        if isinstance(expr, VarRef):
            is_var, _ = self._is_var_param(expr.name)
            level_diff, offset = self._resolve_var(expr.name)
            if is_var:
                if level_diff == 0:
                    self._emit(OP_LOAD, offset)
                else:
                    self._emit(OP_LOAD_L, level_diff, offset)
            else:
                if level_diff == 0:
                    self._emit(OP_PUSH_ADDR, offset)
                else:
                    self._emit(OP_PUSH_ADDR_L, level_diff, offset)
        elif isinstance(expr, ArrayRef):
            raise SyntaxError("array elements as var parameters not yet supported")
        else:
            raise SyntaxError("var parameter must be a variable")

    # ── Statement codegen ────────────────────────────────────

    def _gen_stmt(self, stmt: Statement):
        if isinstance(stmt, AssignStmt):
            if self._resolve_const(stmt.target) is not None:
                raise SyntaxError(f"cannot assign to constant '{stmt.target}'")
            if self._resolve_var_type(stmt.target) == 'string':
                if isinstance(stmt.expr, StringLiteral):
                    _, off = self._resolve_var(stmt.target)
                    self._emit_str_assign_lit(off, self._add_string(stmt.expr.value))
                elif isinstance(stmt.expr, VarRef) and self._resolve_var_type(
                        stmt.expr.name) == 'string':
                    _, dst = self._resolve_var(stmt.target)
                    _, src = self._resolve_var(stmt.expr.name)
                    self._emit_str_copy(dst, src)
                else:
                    raise SyntaxError(
                        "string assignment expects a literal or string variable")
                return
            t = self._gen_expr(stmt.expr)
            self._emit_store_var(stmt.target, t)

        elif isinstance(stmt, ArrayAssignStmt):
            self._gen_expr(stmt.index)
            t = self._gen_expr(stmt.expr)
            if t == 'real':
                self._emit(OP_FTOI)
            self._emit_store_array(stmt.name)

        elif isinstance(stmt, CallStmt):
            lower = stmt.name.lower()
            if lower in ('delay', 'vt100', 'vt100_pos', 'vt100_scroll'):
                self._gen_call(stmt.name, stmt.args)
            else:
                sub_info = self._subroutines.get(lower)
                if sub_info is None:
                    raise SyntaxError(f"undefined procedure: '{stmt.name}'")
                self._gen_call(stmt.name, stmt.args)

        elif isinstance(stmt, ReadlnStmt):
            vtype = self._resolve_var_type(stmt.var_name)
            if vtype == 'string':
                _, off = self._resolve_var(stmt.var_name)
                self._emit(OP_CSP, CSP_READLN_STR, off & 0xFF, (off >> 8) & 0xFF)
            elif vtype == 'real':
                self._emit_csp(CSP_READLN_REAL)
                self._emit_store_var(stmt.var_name, 'real')
            else:
                self._emit_csp(CSP_READLN_INT)
                self._emit_store_var(stmt.var_name, 'integer')

        elif isinstance(stmt, WritelnStmt):
            if stmt.arg is None:
                self._emit_csp(CSP_WRITELN_NOARG)
            elif isinstance(stmt.arg, VarRef) and self._resolve_var_type(
                    stmt.arg.name) == 'string':
                _, off = self._resolve_var(stmt.arg.name)
                self._emit(OP_CSP, CSP_WRITELN_STR, off & 0xFF, (off >> 8) & 0xFF)
            elif self._is_string_expr(stmt.arg):
                self._gen_expr(stmt.arg)
                self._emit_csp(CSP_WRITELN)
            elif isinstance(stmt.arg, ChrExpr):
                self._gen_expr(stmt.arg)
                self._emit_csp(CSP_WRITE_CHAR)
                self._emit_csp(CSP_WRITELN_NOARG)
            else:
                t = self._gen_expr(stmt.arg)
                if t == 'real':
                    self._emit_csp(CSP_WRITELN_REAL)
                else:
                    self._emit_csp(CSP_WRITELN_INT)

        elif isinstance(stmt, WriteStmt):
            if isinstance(stmt.arg, VarRef) and self._resolve_var_type(
                    stmt.arg.name) == 'string':
                _, off = self._resolve_var(stmt.arg.name)
                self._emit(OP_CSP, CSP_WRITE_STR, off & 0xFF, (off >> 8) & 0xFF)
            elif self._is_string_expr(stmt.arg):
                self._gen_expr(stmt.arg)
                self._emit_csp(CSP_WRITE)
            elif isinstance(stmt.arg, ChrExpr):
                self._gen_expr(stmt.arg)
                self._emit_csp(CSP_WRITE_CHAR)
            else:
                t = self._gen_expr(stmt.arg)
                if t == 'real':
                    self._emit_csp(CSP_WRITE_REAL)
                else:
                    self._emit_csp(CSP_WRITE_INT)

        elif isinstance(stmt, PokeStmt):
            t = self._gen_expr(stmt.page)
            if t == 'real':
                self._emit(OP_FTOI)
            t = self._gen_expr(stmt.addr)
            if t == 'real':
                self._emit(OP_FTOI)
            t = self._gen_expr(stmt.value)
            if t == 'real':
                self._emit(OP_FTOI)
            self._emit_csp(CSP_POKE)

        elif isinstance(stmt, IfStmt):
            self._gen_if(stmt)
        elif isinstance(stmt, WhileStmt):
            self._gen_while(stmt)
        elif isinstance(stmt, RepeatStmt):
            self._gen_repeat(stmt)
        elif isinstance(stmt, ForStmt):
            self._gen_for(stmt)
        elif isinstance(stmt, CompoundStmt):
            for s in stmt.statements:
                self._gen_stmt(s)

    def _gen_if(self, stmt: IfStmt):
        ct = self._gen_expr(stmt.condition)
        if ct == 'real':
            self._emit(OP_FTOI)
        jpc_pos = self._emit_jpc()
        self._gen_stmt(stmt.then_stmt)
        if stmt.else_stmt is not None:
            jmp_pos = self._emit_jmp()
            self._patch_jump(jpc_pos, self._code_pos())
            self._gen_stmt(stmt.else_stmt)
            self._patch_jump(jmp_pos, self._code_pos())
        else:
            self._patch_jump(jpc_pos, self._code_pos())

    def _gen_while(self, stmt: WhileStmt):
        loop_start = self._code_pos()
        ct = self._gen_expr(stmt.condition)
        if ct == 'real':
            self._emit(OP_FTOI)
        jpc_pos = self._emit_jpc()
        self._gen_stmt(stmt.body)
        jmp_pos = self._emit_jmp()
        self._patch_jump(jmp_pos, loop_start)
        self._patch_jump(jpc_pos, self._code_pos())

    def _gen_repeat(self, stmt: RepeatStmt):
        loop_start = self._code_pos()
        for s in stmt.statements:
            self._gen_stmt(s)
        ct = self._gen_expr(stmt.condition)
        if ct == 'real':
            self._emit(OP_FTOI)
        jpc_pos = self._code_pos()
        self._emit(OP_JPC, 0x00, 0x00)
        self._patch_jump(jpc_pos, loop_start)

    def _gen_for(self, stmt: ForStmt):
        limit_offset = self._alloc_hidden_var('for_end')
        self._for_counter += 1

        self._gen_expr(stmt.start)
        self._emit_store_var(stmt.var_name)
        self._gen_expr(stmt.end_expr)
        self._emit(OP_STORE, limit_offset)

        loop_start = self._code_pos()
        self._emit_load_var(stmt.var_name)
        self._emit(OP_LOAD, limit_offset)
        if stmt.direction == 'to':
            self._emit(OP_GT)
        else:
            self._emit(OP_LT)
        jpc_body = self._emit_jpc()
        jmp_end = self._emit_jmp()

        self._patch_jump(jpc_body, self._code_pos())
        self._gen_stmt(stmt.body)

        self._emit_load_var(stmt.var_name)
        self._emit(OP_LOAD, limit_offset)
        self._emit(OP_EQ)
        jpc_inc = self._emit_jpc()
        jmp_end2 = self._emit_jmp()

        self._patch_jump(jpc_inc, self._code_pos())
        self._emit_load_var(stmt.var_name)
        self._emit_lit16(1)
        if stmt.direction == 'to':
            self._emit(OP_ADD)
        else:
            self._emit(OP_SUB)
        self._emit_store_var(stmt.var_name)
        jmp_loop = self._emit_jmp()
        self._patch_jump(jmp_loop, loop_start)

        end_pos = self._code_pos()
        self._patch_jump(jmp_end, end_pos)
        self._patch_jump(jmp_end2, end_pos)

    # ── Subroutine codegen ───────────────────────────────────

    def _gen_subroutine(self, sub: Subroutine, definition_level: int):
        is_func = isinstance(sub, FuncDecl)
        sub_name = sub.name.lower()
        return_type = sub.return_type if is_func else ''

        # Count nparams as 16-bit slots (real params take 2 slots each)
        nparams_slots = 0
        for p in sub.params:
            if p.is_var:
                nparams_slots += 1
            elif p.param_type == 'real':
                nparams_slots += 2
            else:
                nparams_slots += 1

        code_addr = self._code_pos()
        self._subroutines[sub_name] = SubroutineInfo(
            code_offset=code_addr,
            params=[p.name for p in sub.params],
            param_types=[p.param_type for p in sub.params],
            is_function=is_func,
            return_type=return_type,
            definition_level=definition_level,
            is_var_param=[p.is_var for p in sub.params]
        )

        if is_func:
            start_offset = 6 if return_type == 'real' else 4
        else:
            start_offset = 2
        body_level = definition_level + 1

        # is_function encoding: 0=proc, 1=int func, 2=real func
        is_func_byte = 0
        if is_func:
            is_func_byte = 2 if return_type == 'real' else 1

        self._push_scope(
            level=body_level, is_function=is_func,
            function_name=sub.name if is_func else None,
            function_return_type=return_type if is_func else None,
            start_offset=start_offset
        )

        for cd in sub.const_decls:
            self._add_const(cd.name, cd.value)
        for param in sub.params:
            if param.is_var:
                self._add_var_param(param.name)
            else:
                self._add_var(param.name, param.param_type)
        for decl in sub.var_decls:
            if isinstance(decl, ArrayDecl):
                self._add_array(decl.name, decl.low, decl.high)
            else:
                for name in decl.names:
                    self._add_var(name, decl.var_type)

        enter_pos = self._code_pos()
        self._emit(OP_ENTER16, 0, 0, nparams_slots, is_func_byte)

        if sub.subroutines:
            jmp_body = self._emit_jmp()
            for nested in sub.subroutines:
                self._gen_subroutine(nested, definition_level=body_level)
            self._patch_jump(jmp_body, self._code_pos())

        for s in sub.body.statements:
            self._gen_stmt(s)

        sz = self._scope.next_offset
        self.code[enter_pos + 1] = sz & 0xFF
        self.code[enter_pos + 2] = (sz >> 8) & 0xFF
        self._emit(OP_RET, is_func_byte)
        self._pop_scope()

    # ── Binary generation ────────────────────────────────────

    def _build_ot_header(self) -> bytes:
        return bytes([
            0x4F, 0x54,                          # magic "OT"
            0x01,                                 # format version
            (self.base >> 16) & 0xFF,             # page
            (self.base >> 8) & 0xFF,              # high
            self.base & 0xFF,                     # low
        ])

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
        self._push_scope(level=0, is_function=False, start_offset=2)

        for cd in program.const_decls:
            self._add_const(cd.name, cd.value)

        for decl in program.var_decls:
            if isinstance(decl, ArrayDecl):
                self._add_array(decl.name, decl.low, decl.high)
            else:
                for name in decl.names:
                    self._add_var(name, decl.var_type)

        if program.subroutines:
            jmp_main = self._emit_jmp()
            for sub in program.subroutines:
                self._gen_subroutine(sub, definition_level=0)
            self._patch_jump(jmp_main, self._code_pos())

        enter_pos = self._code_pos()
        self._emit(OP_ENTER16, 0, 0, 0, 0)

        for stmt in program.statements:
            self._gen_stmt(stmt)

        sz = self._scope.next_offset
        self.code[enter_pos + 1] = sz & 0xFF
        self.code[enter_pos + 2] = (sz >> 8) & 0xFF

        self.code.append(OP_HALT)
        self._pop_scope()

        # In RAM, OT header is stripped by loader; first byte at load addr is stub.
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
        ot_header = self._build_ot_header()

        return ot_header + bytes(stub) + bytes(header + self.code + data)

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
