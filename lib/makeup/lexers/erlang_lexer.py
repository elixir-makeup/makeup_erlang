# -*- coding: utf-8 -*-

# -------------------------------------------------------------------------------
# Erlang lexer from Pygments
#   * use as reference until our implementation is better
# -------------------------------------------------------------------------------

"""
    pygments.lexers.erlang
    ~~~~~~~~~~~~~~~~~~~~~~

    Lexers for Erlang.

    :copyright: Copyright 2006-2015 by the Pygments team, see AUTHORS.
    :license: BSD, see LICENSE for details.
"""

import re

from pygments.lexer import Lexer, RegexLexer, bygroups, words, do_insertions, \
    include, default
from pygments.token import Text, Comment, Operator, Keyword, Name, String, \
    Number, Punctuation, Generic

__all__ = ['ErlangLexer', 'ErlangShellLexer']


line_re = re.compile('.*?\n')


class ErlangLexer(RegexLexer):
    """
    For the Erlang functional programming language.

    Blame Jeremy Thurgood (http://jerith.za.net/).

    .. versionadded:: 0.9
    """

    name = 'Erlang'
    aliases = ['erlang']
    filenames = ['*.erl', '*.hrl', '*.es', '*.escript']
    mimetypes = ['text/x-erlang']

    keywords = (
        'after', 'begin', 'case', 'catch', 'cond', 'end', 'fun', 'if',
        'let', 'of', 'query', 'receive', 'try', 'when',
    )

    builtins = (  # See erlang(3) man page
        'abs', 'append_element', 'apply', 'atom_to_list', 'binary_to_list',
        'bitstring_to_list', 'binary_to_term', 'bit_size', 'bump_reductions',
        'byte_size', 'cancel_timer', 'check_process_code', 'delete_module',
        'demonitor', 'disconnect_node', 'display', 'element', 'erase', 'exit',
        'float', 'float_to_list', 'fun_info', 'fun_to_list',
        'function_exported', 'garbage_collect', 'get', 'get_keys',
        'group_leader', 'hash', 'hd', 'integer_to_list', 'iolist_to_binary',
        'iolist_size', 'is_atom', 'is_binary', 'is_bitstring', 'is_boolean',
        'is_builtin', 'is_float', 'is_function', 'is_integer', 'is_list',
        'is_number', 'is_pid', 'is_port', 'is_process_alive', 'is_record',
        'is_reference', 'is_tuple', 'length', 'link', 'list_to_atom',
        'list_to_binary', 'list_to_bitstring', 'list_to_existing_atom',
        'list_to_float', 'list_to_integer', 'list_to_pid', 'list_to_tuple',
        'load_module', 'localtime_to_universaltime', 'make_tuple', 'md5',
        'md5_final', 'md5_update', 'memory', 'module_loaded', 'monitor',
        'monitor_node', 'node', 'nodes', 'open_port', 'phash', 'phash2',
        'pid_to_list', 'port_close', 'port_command', 'port_connect',
        'port_control', 'port_call', 'port_info', 'port_to_list',
        'process_display', 'process_flag', 'process_info', 'purge_module',
        'put', 'read_timer', 'ref_to_list', 'register', 'resume_process',
        'round', 'send', 'send_after', 'send_nosuspend', 'set_cookie',
        'setelement', 'size', 'spawn', 'spawn_link', 'spawn_monitor',
        'spawn_opt', 'split_binary', 'start_timer', 'statistics',
        'suspend_process', 'system_flag', 'system_info', 'system_monitor',
        'system_profile', 'term_to_binary', 'tl', 'trace', 'trace_delivered',
        'trace_info', 'trace_pattern', 'trunc', 'tuple_size', 'tuple_to_list',
        'universaltime_to_localtime', 'unlink', 'unregister', 'whereis'
    )

    operators = r'(\+\+?|--?|\*|/|<|>|/=|=:=|=/=|=<|>=|==?|<-|!|\?)'
    word_operators = (
        'and', 'andalso', 'band', 'bnot', 'bor', 'bsl', 'bsr', 'bxor',
        'div', 'not', 'or', 'orelse', 'rem', 'xor'
    )

    atom_re = r"(?:[a-z]\w*|'[^\n']*[^\\]')"

    variable_re = r'(?:[A-Z_]\w*)'

    esc_char_re = r'[bdefnrstv\'"\\]'
    esc_octal_re = r'[0-7][0-7]?[0-7]?'
    esc_hex_re = r'(?:x[0-9a-fA-F]{2}|x\{[0-9a-fA-F]+\})'
    esc_ctrl_re = r'\^[a-zA-Z]'
    escape_re = r'(?:\\(?:'+esc_char_re+r'|'+esc_octal_re+r'|'+esc_hex_re+r'|'+esc_ctrl_re+r'))'

    macro_re = r'(?:'+variable_re+r'|'+atom_re+r')'

    base_re = r'(?:[2-9]|[12][0-9]|3[0-6])'

    tokens = {
        'root': [
            (r'\s+', Text),
            (r'%.*\n', Comment),
            (words(keywords, suffix=r'\b'), Keyword),
            (words(builtins, suffix=r'\b'), Name.Builtin),
            (words(word_operators, suffix=r'\b'), Operator.Word),
            (r'^-', Punctuation, 'directive'),
            (operators, Operator),
            (r'"', String, 'string'),
            (r'<<', Name.Label),
            (r'>>', Name.Label),
            ('(' + atom_re + ')(:)', bygroups(Name.Namespace, Punctuation)),
            ('(?:^|(?<=:))(' + atom_re + r')(\s*)(\()',
             bygroups(Name.Function, Text, Punctuation)),
            (r'[+-]?' + base_re + r'#[0-9a-zA-Z]+', Number.Integer),
            (r'[+-]?\d+', Number.Integer),
            (r'[+-]?\d+.\d+', Number.Float),
            (r'[]\[:_@\".{}()|;,]', Punctuation),
            (variable_re, Name.Variable),
            (atom_re, Name),
            (r'\?'+macro_re, Name.Constant),
            (r'\$(?:'+escape_re+r'|\\[ %]|[^\\])', String.Char),
            (r'#'+atom_re+r'(:?\.'+atom_re+r')?', Name.Label),

            # Erlang script shebang
            (r'\A#!.+\n', Comment.Hashbang),

            # EEP 43: Maps
            # http://www.erlang.org/eeps/eep-0043.html
            (r'#\{', Punctuation, 'map_key'),
        ],
        'string': [
            (escape_re, String.Escape),
            (r'"', String, '#pop'),
            (r'~[0-9.*]*[~#+BPWXb-ginpswx]', String.Interpol),
            (r'[^"\\~]+', String),
            (r'~', String),
        ],
        'directive': [
            (r'(define)(\s*)(\()('+macro_re+r')',
             bygroups(Name.Entity, Text, Punctuation, Name.Constant), '#pop'),
            (r'(record)(\s*)(\()('+macro_re+r')',
             bygroups(Name.Entity, Text, Punctuation, Name.Label), '#pop'),
            (atom_re, Name.Entity, '#pop'),
        ],
        'map_key': [
            include('root'),
            (r'=>', Punctuation, 'map_val'),
            (r':=', Punctuation, 'map_val'),
            (r'\}', Punctuation, '#pop'),
        ],
        'map_val': [
            include('root'),
            (r',', Punctuation, '#pop'),
            (r'(?=\})', Punctuation, '#pop'),
        ],
    }


class ErlangShellLexer(Lexer):
    """
    Shell sessions in erl (for Erlang code).

    .. versionadded:: 1.1
    """
    name = 'Erlang erl session'
    aliases = ['erl']
    filenames = ['*.erl-sh']
    mimetypes = ['text/x-erl-shellsession']

    _prompt_re = re.compile(r'\d+>(?=\s|\Z)')

    def get_tokens_unprocessed(self, text):
        erlexer = ErlangLexer(**self.options)

        curcode = ''
        insertions = []
        for match in line_re.finditer(text):
            line = match.group()
            m = self._prompt_re.match(line)
            if m is not None:
                end = m.end()
                insertions.append((len(curcode),
                                   [(0, Generic.Prompt, line[:end])]))
                curcode += line[end:]
            else:
                if curcode:
                    for item in do_insertions(insertions,
                                              erlexer.get_tokens_unprocessed(curcode)):
                        yield item
                    curcode = ''
                    insertions = []
                if line.startswith('*'):
                    yield match.start(), Generic.Traceback, line
                else:
                    yield match.start(), Generic.Output, line
        if curcode:
            for item in do_insertions(insertions,
                                      erlexer.get_tokens_unprocessed(curcode)):
                yield item
