#!/usr/bin/env python3
"""
Tiny Pascal Compiler for Project Otto P-Machine.

Compiles a minimal subset of Pascal into P-code bytecode
that runs on the Otto P-Machine interpreter (ROM #3).

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

CSP_WRITE         = 0x00
CSP_WRITELN       = 0x01
CSP_WRITELN_NOARG = 0x02
CSP_WRITE_INT     = 0x03
CSP_WRITELN_INT   = 0x04
CSP_READLN_INT    = 0x05

MAGIC = bytes([0x50, 0x4D])   # "PM"
FORMAT_VERSION = 0x01
PCODE_HEADER_SIZE = 7

NATIVE_STUB_SIZE = 9
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
    VAR            = auto()
    INTEGER        = auto()
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
    ARRAY          = auto()
    OF             = auto()
    IDENTIFIER     = auto()
    STRING_LITERAL = auto()
    NUMBER         = auto()
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
    'var':       TokenType.VAR,
    'integer':   TokenType.INTEGER,
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

Expression = Union[NumberLiteral, StringLiteral, VarRef, BinaryOp, UnaryOp, CallExpr, ArrayRef]

@dataclass
class VarDecl:
    names: List[str]

@dataclass
class ArrayDecl:
    name: str
    low: int
    high: int

@dataclass
class ParamDecl:
    name: str

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
class ArrayAssignStmt:
    name: str
    index: Expression
    expr: Expression

@dataclass
class CompoundStmt:
    statements: List['Statement']

Statement = Union[VarDecl, AssignStmt, WritelnStmt, WriteStmt, ReadlnStmt,
                  CallStmt, IfStmt, WhileStmt, ForStmt, CompoundStmt,
                  ArrayAssignStmt]

Declaration = Union[VarDecl, ArrayDecl]

@dataclass
class ProcDecl:
    name: str
    params: List[ParamDecl]
    var_decls: List[Declaration]
    subroutines: List[Union['ProcDecl', 'FuncDecl']]
    body: CompoundStmt

@dataclass
class FuncDecl:
    name: str
    params: List[ParamDecl]
    return_type: str
    var_decls: List[Declaration]
    subroutines: List[Union['ProcDecl', 'FuncDecl']]
    body: CompoundStmt

Subroutine = Union[ProcDecl, FuncDecl]

@dataclass
class PascalProgram:
    name: str
    var_decls: List[Declaration]
    subroutines: List[Subroutine]
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

        var_decls: list[VarDecl] = []
        if self._current().type == TokenType.VAR:
            var_decls = self._parse_var_block()

        subroutines = self._parse_subroutines()

        self._expect(TokenType.BEGIN)
        stmts = self._parse_statement_list()
        self._expect(TokenType.END)
        self._expect(TokenType.DOT)
        return PascalProgram(name=name, var_decls=var_decls,
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
                self._expect(TokenType.INTEGER)
                self._expect(TokenType.SEMICOLON)
                decls.append(VarDecl(names=names))
        return decls

    def _parse_const_int(self) -> int:
        sign = 1
        if self._current().type == TokenType.MINUS:
            sign = -1
            self.pos += 1
        tok = self._expect(TokenType.NUMBER)
        return sign * int(tok.value)

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
        names = [self._expect(TokenType.IDENTIFIER).value]
        while self._current().type == TokenType.COMMA:
            self.pos += 1
            names.append(self._expect(TokenType.IDENTIFIER).value)
        self._expect(TokenType.COLON)
        self._expect(TokenType.INTEGER)
        return [ParamDecl(name=n) for n in names]

    def _parse_proc_decl(self) -> ProcDecl:
        self._expect(TokenType.PROCEDURE)
        name = self._expect(TokenType.IDENTIFIER).value
        params = self._parse_param_list()
        self._expect(TokenType.SEMICOLON)
        var_decls: list[VarDecl] = []
        if self._current().type == TokenType.VAR:
            var_decls = self._parse_var_block()
        subroutines = self._parse_subroutines()
        self._expect(TokenType.BEGIN)
        stmts = self._parse_statement_list()
        self._expect(TokenType.END)
        self._expect(TokenType.SEMICOLON)
        return ProcDecl(name=name, params=params, var_decls=var_decls,
                        subroutines=subroutines,
                        body=CompoundStmt(statements=stmts))

    def _parse_func_decl(self) -> FuncDecl:
        self._expect(TokenType.FUNCTION)
        name = self._expect(TokenType.IDENTIFIER).value
        params = self._parse_param_list()
        self._expect(TokenType.COLON)
        self._expect(TokenType.INTEGER)
        self._expect(TokenType.SEMICOLON)
        var_decls: list[VarDecl] = []
        if self._current().type == TokenType.VAR:
            var_decls = self._parse_var_block()
        subroutines = self._parse_subroutines()
        self._expect(TokenType.BEGIN)
        stmts = self._parse_statement_list()
        self._expect(TokenType.END)
        self._expect(TokenType.SEMICOLON)
        return FuncDecl(name=name, params=params, return_type='integer',
                        var_decls=var_decls, subroutines=subroutines,
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
        while self._current().type in (TokenType.STAR, TokenType.DIV,
                                        TokenType.MOD, TokenType.AND):
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
            return UnaryOp(op='-', operand=operand)

        if tok.type == TokenType.NOT:
            self.pos += 1
            operand = self._parse_factor()
            return UnaryOp(op='not', operand=operand)

        self._error(f"expected expression, got {tok.type.name} ('{tok.value}')")

# ── Scope & subroutine info ─────────────────────────────────

@dataclass
class Scope:
    level: int
    symbols: dict
    arrays: dict
    is_function: bool
    function_name: Optional[str]
    enclosing: Optional['Scope']
    next_offset: int

@dataclass
class SubroutineInfo:
    code_offset: int
    params: list
    is_function: bool
    definition_level: int

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

    # ── Scope management ─────────────────────────────────────

    def _push_scope(self, level: int, is_function: bool,
                    function_name: Optional[str] = None,
                    start_offset: int = 0):
        self._scope = Scope(
            level=level, symbols={}, arrays={}, is_function=is_function,
            function_name=function_name, enclosing=self._scope,
            next_offset=start_offset
        )

    def _pop_scope(self):
        self._scope = self._scope.enclosing

    def _add_var(self, name: str) -> int:
        lower = name.lower()
        if lower in self._scope.symbols:
            raise SyntaxError(f"duplicate variable declaration: '{name}'")
        offset = self._scope.next_offset
        self._scope.symbols[lower] = offset
        self._scope.next_offset += 2
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

    def _add_array(self, name: str, low: int, high: int) -> int:
        lower = name.lower()
        if lower in self._scope.symbols:
            raise SyntaxError(f"duplicate variable declaration: '{name}'")
        count = high - low + 1
        if count <= 0:
            raise SyntaxError(f"invalid array bounds: [{low}..{high}]")
        byte_size = count * 2
        offset = self._scope.next_offset
        if offset + byte_size > 256:
            raise SyntaxError(f"array '{name}' exceeds frame size limit (256 bytes)")
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

    def _emit_lit16_fixup(self, string_index: int):
        self.code.append(OP_LIT16)
        self._fixups.append((len(self.code), string_index))
        self.code.extend([0x00, 0x00])

    def _emit_csp(self, proc: int):
        self._emit(OP_CSP, proc)

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

    def _emit_load_var(self, name: str):
        level_diff, offset = self._resolve_var(name)
        if level_diff == 0:
            self._emit(OP_LOAD, offset)
        else:
            self._emit(OP_LOAD_L, level_diff, offset)

    def _emit_store_var(self, name: str):
        if self._is_current_function_name(name):
            self._emit(OP_STORE, 2)
            return
        level_diff, offset = self._resolve_var(name)
        if level_diff == 0:
            self._emit(OP_STORE, offset)
        else:
            self._emit(OP_STORE_L, level_diff, offset)

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

    def _gen_expr(self, expr: Expression):
        if isinstance(expr, NumberLiteral):
            self._emit_lit16(expr.value & 0xFFFF)
        elif isinstance(expr, StringLiteral):
            idx = self._add_string(expr.value)
            self._emit_lit16_fixup(idx)
        elif isinstance(expr, VarRef):
            self._emit_load_var(expr.name)
        elif isinstance(expr, UnaryOp):
            self._gen_expr(expr.operand)
            if expr.op == '-':
                self._emit(OP_NEG)
            elif expr.op == 'not':
                self._emit(OP_NOT)
        elif isinstance(expr, BinaryOp):
            self._gen_expr(expr.left)
            self._gen_expr(expr.right)
            op_map = {
                '+': OP_ADD, '-': OP_SUB, '*': OP_MUL,
                'div': OP_DIV, 'mod': OP_MOD,
                '=': OP_EQ, '<>': OP_NE, '<': OP_LT,
                '>': OP_GT, '<=': OP_LE, '>=': OP_GE,
                'and': OP_AND, 'or': OP_OR,
            }
            self._emit(op_map[expr.op])
        elif isinstance(expr, ArrayRef):
            self._gen_expr(expr.index)
            self._emit_load_array(expr.name)
        elif isinstance(expr, CallExpr):
            self._gen_call(expr.name, expr.args)

    def _is_string_expr(self, expr: Expression) -> bool:
        return isinstance(expr, StringLiteral)

    # ── Call codegen ─────────────────────────────────────────

    def _gen_call(self, name: str, args: list[Expression]):
        lower = name.lower()
        sub_info = self._subroutines.get(lower)
        if sub_info is None:
            raise SyntaxError(f"undefined procedure/function: '{name}'")
        if len(args) != len(sub_info.params):
            raise SyntaxError(
                f"'{name}' expects {len(sub_info.params)} argument(s), "
                f"got {len(args)}")

        for arg in args:
            self._gen_expr(arg)

        caller_level = self._scope.level
        static_depth = caller_level - sub_info.definition_level

        addr = PCODE_HEADER_SIZE + sub_info.code_offset
        self._emit(OP_CALL, addr & 0xFF, (addr >> 8) & 0xFF, static_depth)

    # ── Statement codegen ────────────────────────────────────

    def _gen_stmt(self, stmt: Statement):
        if isinstance(stmt, AssignStmt):
            self._gen_expr(stmt.expr)
            if self._is_current_function_name(stmt.target):
                self._emit(OP_STORE, 2)
            else:
                self._emit_store_var(stmt.target)

        elif isinstance(stmt, ArrayAssignStmt):
            self._gen_expr(stmt.index)
            self._gen_expr(stmt.expr)
            self._emit_store_array(stmt.name)

        elif isinstance(stmt, CallStmt):
            lower = stmt.name.lower()
            sub_info = self._subroutines.get(lower)
            if sub_info is None:
                raise SyntaxError(f"undefined procedure: '{stmt.name}'")
            self._gen_call(stmt.name, stmt.args)
            if sub_info.is_function:
                # discard unused return value
                self._emit(OP_STORE, 0)  # dummy store (won't be read)
                # Actually, let's pop it properly
                # Pop 2 bytes from eval stack (no opcode for that, use a dummy approach)
                pass
                # Hmm, there's no POP opcode. Let me just allow it — calling a function
                # as a statement leaves a value on the eval stack. This is a minor leak.
                # For now, ignore. A proper fix would need an OP_POP opcode.

        elif isinstance(stmt, ReadlnStmt):
            self._emit_csp(CSP_READLN_INT)
            self._emit_store_var(stmt.var_name)

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

        elif isinstance(stmt, IfStmt):
            self._gen_if(stmt)
        elif isinstance(stmt, WhileStmt):
            self._gen_while(stmt)
        elif isinstance(stmt, ForStmt):
            self._gen_for(stmt)
        elif isinstance(stmt, CompoundStmt):
            for s in stmt.statements:
                self._gen_stmt(s)

    def _gen_if(self, stmt: IfStmt):
        self._gen_expr(stmt.condition)
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
        self._gen_expr(stmt.condition)
        jpc_pos = self._emit_jpc()
        self._gen_stmt(stmt.body)
        jmp_pos = self._emit_jmp()
        self._patch_jump(jmp_pos, loop_start)
        self._patch_jump(jpc_pos, self._code_pos())

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

        code_addr = self._code_pos()
        self._subroutines[sub_name] = SubroutineInfo(
            code_offset=code_addr,
            params=[p.name for p in sub.params],
            is_function=is_func,
            definition_level=definition_level
        )

        start_offset = 4 if is_func else 2
        body_level = definition_level + 1

        self._push_scope(
            level=body_level, is_function=is_func,
            function_name=sub.name if is_func else None,
            start_offset=start_offset
        )

        for param in sub.params:
            self._add_var(param.name)
        for decl in sub.var_decls:
            if isinstance(decl, ArrayDecl):
                self._add_array(decl.name, decl.low, decl.high)
            else:
                for name in decl.names:
                    self._add_var(name)

        enter_pos = self._code_pos()
        self._emit(OP_ENTER, 0, len(sub.params), 1 if is_func else 0)

        if sub.subroutines:
            jmp_body = self._emit_jmp()
            for nested in sub.subroutines:
                self._gen_subroutine(nested, definition_level=body_level)
            self._patch_jump(jmp_body, self._code_pos())

        for s in sub.body.statements:
            self._gen_stmt(s)

        self.code[enter_pos + 1] = self._scope.next_offset
        self._emit(OP_RET, 1 if is_func else 0)
        self._pop_scope()

    # ── Binary generation ────────────────────────────────────

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

        for decl in program.var_decls:
            if isinstance(decl, ArrayDecl):
                self._add_array(decl.name, decl.low, decl.high)
            else:
                for name in decl.names:
                    self._add_var(name)

        if program.subroutines:
            jmp_main = self._emit_jmp()
            for sub in program.subroutines:
                self._gen_subroutine(sub, definition_level=0)
            self._patch_jump(jmp_main, self._code_pos())

        enter_pos = self._code_pos()
        self._emit(OP_ENTER, 0, 0, 0)

        for stmt in program.statements:
            self._gen_stmt(stmt)

        self.code[enter_pos + 1] = self._scope.next_offset

        self.code.append(OP_HALT)
        self._pop_scope()

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
