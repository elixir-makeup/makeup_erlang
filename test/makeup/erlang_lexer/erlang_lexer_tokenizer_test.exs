defmodule ErlangLexerTokenizer do
  use ExUnit.Case, async: false
  import Makeup.Lexers.ErlangLexer.Testing, only: [lex: 1]

  test "empty string" do
    assert lex("") == []
  end

  test "whitespace" do
    assert lex(" ") == [{:whitespace, %{}, " "}]
    assert lex("\n") == [{:whitespace, %{}, "\n"}]
    assert lex("\t") == [{:whitespace, %{}, "\t"}]
    assert lex("\f") == [{:whitespace, %{}, "\f"}]
    assert lex("\s") == [{:whitespace, %{}, "\s"}]
  end

  test "character" do
    assert lex("$a") == [{:string_char, %{}, "$a"}]
    assert lex("$\\ ") == [{:string_char, %{}, "$\\ "}]
    assert lex("$🫂") == [{:string_char, %{}, "$🫂"}]
  end

  describe "character escape sequences" do
    test "named escapes" do
      assert lex("$\\n") == [{:string_char, %{}, "$\\n"}]
      assert lex("$\\t") == [{:string_char, %{}, "$\\t"}]
      assert lex("$\\\\") == [{:string_char, %{}, "$\\\\"}]
      assert lex("$\\\"") == [{:string_char, %{}, "$\\\""}]
    end

    test "octal escape" do
      assert lex("$\\7") == [{:string_char, %{}, "$\\7"}]
      assert lex("$\\07") == [{:string_char, %{}, "$\\07"}]
      assert lex("$\\077") == [{:string_char, %{}, "$\\077"}]
    end

    test "hex escape (two-digit form)" do
      assert lex("$\\xFF") == [{:string_char, %{}, "$\\xFF"}]
      assert lex("$\\x4a") == [{:string_char, %{}, "$\\x4a"}]
    end

    test "hex escape (braced form)" do
      assert lex("$\\x{1F600}") == [{:string_char, %{}, "$\\x{1F600}"}]
      assert lex("$\\x{0}") == [{:string_char, %{}, "$\\x{0}"}]
    end

    test "control escape" do
      assert lex("$\\^A") == [{:string_char, %{}, "$\\^A"}]
      assert lex("$\\^z") == [{:string_char, %{}, "$\\^z"}]
    end
  end

  test "comment" do
    assert lex("%abc") == [{:comment_single, %{}, "%abc"}]
    assert lex("% abc") == [{:comment_single, %{}, "% abc"}]

    assert lex("% abc\n") == [
             {:comment_single, %{}, "% abc"},
             {:whitespace, %{}, "\n"}
           ]

    assert lex("% abc\n123") == [
             {:comment_single, %{}, "% abc"},
             {:whitespace, %{}, "\n"},
             {:number_integer, %{}, "123"}
           ]
  end

  test "namespace" do
    assert lex("mod:") == [
             {:name_class, %{}, "mod"},
             {:punctuation, %{}, ":"}
           ]
  end

  test "variable" do
    assert lex("A") == [{:name, %{}, "A"}]
    assert lex("A1") == [{:name, %{}, "A1"}]
    assert lex("Ab1") == [{:name, %{}, "Ab1"}]
    assert lex("A_b1") == [{:name, %{}, "A_b1"}]
  end

  describe "underscore-prefixed variables" do
    test "underscore + digit lexes as a single variable" do
      assert lex("_5") == [{:name, %{}, "_5"}]
    end

    test "underscore + lowercase lexes as a single variable" do
      assert lex("_unused") == [{:name, %{}, "_unused"}]
    end

    test "underscore + uppercase lexes as a single variable" do
      assert lex("_X") == [{:name, %{}, "_X"}]
    end

    test "bare underscore (wildcard) stays as punctuation" do
      # Pattern wildcard. Treat as punctuation so themes can render it
      # distinctly from a variable name.
      assert [
               {:keyword, %{}, "case"},
               {:whitespace, %{}, " "},
               {:name, %{}, "X"},
               {:whitespace, %{}, " "},
               {:keyword, %{}, "of"},
               {:whitespace, %{}, " "},
               {:punctuation, %{}, "_"},
               {:whitespace, %{}, " "},
               {:punctuation, %{}, "->"} | _
             ] = lex("case X of _ -> ok end")
    end
  end

  test "function call" do
    assert lex("f(") == [
             {:name_function, %{}, "f"},
             {:punctuation, %{group_id: "group-1"}, "("}
           ]

    assert lex("f(1)") == [
             {:name_function, %{}, "f"},
             {:punctuation, %{group_id: "group-1"}, "("},
             {:number_integer, %{}, "1"},
             {:punctuation, %{group_id: "group-1"}, ")"}
           ]
  end

  test "qualified function call" do
    assert lex("mod:f(1)") == [
             {:name_class, %{}, "mod"},
             {:punctuation, %{}, ":"},
             {:name_function, %{}, "f"},
             {:punctuation, %{group_id: "group-1"}, "("},
             {:number_integer, %{}, "1"},
             {:punctuation, %{group_id: "group-1"}, ")"}
           ]
  end

  describe "numbers" do
    test "integers in base 10" do
      assert lex("123") == [{:number_integer, %{}, "123"}]
    end

    test "integers in weird bases" do
      assert lex("14#34") == [{:number_integer, %{}, "14#34"}]
    end

    test "floating point numbers (normal)" do
      assert lex("1.0") == [{:number_float, %{}, "1.0"}]
      assert lex("12.45") == [{:number_float, %{}, "12.45"}]
    end

    test "floating point numbers (scientific notation)" do
      assert lex("1.05e6") == [{:number_float, %{}, "1.05e6"}]
      assert lex("1.05e12") == [{:number_float, %{}, "1.05e12"}]
      assert lex("1.05e-6") == [{:number_float, %{}, "1.05e-6"}]
      assert lex("1.05e-12") == [{:number_float, %{}, "1.05e-12"}]
      assert lex("1.05e+6") == [{:number_float, %{}, "1.05e+6"}]
      assert lex("1.0e+10") == [{:number_float, %{}, "1.0e+10"}]
    end

    # Numeric separators (`_`) are valid inside numeric literals since OTP 27.
    test "integers with underscore separators" do
      assert lex("1_000") == [{:number_integer, %{}, "1_000"}]
      assert lex("1_000_000") == [{:number_integer, %{}, "1_000_000"}]
    end

    test "floats with underscore separators" do
      assert lex("1_000.5") == [{:number_float, %{}, "1_000.5"}]
      assert lex("3.14_15") == [{:number_float, %{}, "3.14_15"}]
    end

    test "weird-base integers with underscore separators" do
      assert lex("16#FF_FF") == [{:number_integer, %{}, "16#FF_FF"}]
      assert lex("2#1010_1010") == [{:number_integer, %{}, "2#1010_1010"}]
    end

    test "trailing identifier after a number is not absorbed via underscore" do
      # `1_000` is a number; the bare identifier following with whitespace is separate.
      assert [
               {:number_integer, %{}, "1_000"},
               {:whitespace, %{}, " "},
               {:name, %{}, "X"}
             ] = lex("1_000 X")
    end
  end

  describe "charlists" do
    test "tokenize charlist as strings" do
      assert lex(~s/"charlist"/) == [{:string, %{}, ~s/"charlist"/}]
      assert lex(~s/"long char list"/) == [{:string, %{}, ~s/"long char list"/}]
      assert lex(~s/"multi \n line charlist"/) == [{:string, %{}, ~s/"multi \n line charlist"/}]
    end

    test "do not tokenize variables inside charlists" do
      refute {:name, %{}, "Variable"} in lex(~s/"char False_variable list"/)
      refute {:name, %{}, "Variable"} in lex(~s/"FalseVariable"/)
    end

    test "do not tokenize operators inside charlists" do
      refute {:operator_word, %{}, "div"} in lex(~s/"div"/)
      refute {:operator_word, %{}, "div"} in lex(~s/"char div list"/)
    end

    test "tokenizes the interpolation inside a charlist" do
      assert {:string_interpol, %{}, "~p"} in lex(~s/"~p"/)
      assert {:string_interpol, %{}, "~p"} in lex(~s/"some text ~p"/)
      assert {:string_interpol, %{}, "~p"} in lex(~s/"multi line \n text ~p"/)
    end

    test "tokenizes escape of double quotes correctly" do
      # Strings now produce :string_escape sub-tokens for each escape
      # sequence (mirroring the triple-quoted-string behaviour and
      # `makeup_elixir`). Themes can render escapes distinctly from the
      # surrounding string body.
      assert [
               {:string, %{}, ~s/"escape /},
               {:string_escape, %{}, ~s/\\"/},
               {:string, %{}, "double quote"},
               {:string_escape, %{}, ~s/\\"/},
               {:string, %{}, "\""}
             ] = lex(~s/"escape \\"double quote\\""/)

      assert {:string, %{}, ~s/"invalid string\\"/} not in lex(~s/"invalid string\\"/)
    end

    test "tokenizes literal escaped characters correctly" do
      assert [
               {:string, %{}, "\""},
               {:string_escape, %{}, "\\b"},
               {:string, %{}, "\""}
             ] = lex(~s/"\\b"/)

      assert [
               {:string, %{}, "\""},
               {:string_escape, %{}, "\\\\"},
               {:string, %{}, "b\""}
             ] = lex(~s/"\\\\b"/)
    end

    test "tokenizes hex / octal / control escapes inside strings" do
      assert [
               {:string, %{}, ~s/"a/},
               {:string_escape, %{}, ~s/\\xFF/},
               {:string, %{}, "b\""}
             ] = lex(~s/"a\\xFFb"/)

      assert [
               {:string, %{}, ~s/"a/},
               {:string_escape, %{}, "\\077"},
               {:string, %{}, "b\""}
             ] = lex(~s/"a\\077b"/)

      assert [
               {:string, %{}, ~s/"a/},
               {:string_escape, %{}, "\\^A"},
               {:string, %{}, "b\""}
             ] = lex(~s/"a\\^Ab"/)
    end
  end

  describe "binary" do
    test "<<>> syntax" do
      assert lex(~s/<<>>/) == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end

    test "<<\"\">> syntax" do
      assert lex(~s/<<"">>/) == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:string, %{}, ~s/""/},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end

    test "<<\"string\">> syntax" do
      assert lex(~s/<<"string">>/) == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:string, %{}, ~s/"string"/},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end
  end

  describe "triple quoted strings" do
    test "triple quotes" do
      assert lex(~s/"""\nabc\n"""/) == [{:string, %{}, ~s/"""\nabc\n"""/}]
      assert lex(~s/"""\na""bc\n"""/) == [{:string, %{}, ~s/"""\na""bc\n"""/}]

      assert lex(~s/"""\na\\"""bc\n"""/) == [
               {:string, %{}, ~s/"""\na/},
               {:string_escape, %{}, ~s/\\"/},
               {:string, %{}, ~s/""bc\n"""/}
             ]
    end
  end

  @sigil_delimiters [
    {~s["""\n], ~s[\n"""]},
    {"'''\n", "\n'''"},
    {"\"", "\""},
    {"'", "'"},
    {"/", "/"},
    {"{", "}"},
    {"[", "]"},
    {"(", ")"},
    {"<", ">"},
    {"|", "|"},
    {"#", "#"},
    {"`", "`"}
  ]

  describe "sigils" do
    test "sigils with escape" do
      for b <- ["b", "s", ""] do
        for {llim, rlim} <- @sigil_delimiters do
          assert lex(~s/~#{b}#{llim}abc#{rlim}/) == [{:string, %{}, ~s/~#{b}#{llim}abc#{rlim}/}]

          assert lex(~s/~#{b}#{llim}~p#{rlim}/) == [
                   {:string, %{}, ~s/~#{b}#{llim}/},
                   {:string_interpol, %{}, "~p"},
                   {:string, %{}, ~s/#{rlim}/}
                 ]

          if String.length(llim) == 1 do
            assert lex(~s/~#{b}#{llim}a\\#{rlim}bc#{rlim}/) ==
                     [
                       {:string, %{}, ~s/~#{b}#{llim}a/},
                       {:string_escape, %{}, ~s/\\#{rlim}/},
                       {:string, %{}, ~s/bc#{rlim}/}
                     ]
          end
        end
      end
    end

    test "sigils without escape" do
      for b <- ["B", "S"] do
        for {llim, rlim} <- @sigil_delimiters do
          assert lex(~s/~#{b}#{llim}abc#{rlim}/) == [{:string, %{}, ~s/~#{b}#{llim}abc#{rlim}/}]

          assert lex(~s/~#{b}#{llim}~p#{rlim}/) == [
                   {:string, %{}, ~s/~#{b}#{llim}/},
                   {:string_interpol, %{}, "~p"},
                   {:string, %{}, ~s/#{rlim}/}
                 ]

          if String.length(llim) == 1 do
            match = {:string, %{}, ~s/~#{b}#{llim}a\\#{rlim}/}
            assert [^match | _] = lex(~s/~#{b}#{llim}a\\#{rlim}bc#{rlim}/)
          end
        end
      end
    end
  end

  describe "comprehensions" do
    test "list" do
      assert lex("[A||A<-B]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<-"},
               {:name, %{}, "B"},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]

      assert lex("[A||A<-B,true]") ==
               [
                 {:punctuation, %{group_id: "group-1"}, "["},
                 {:name, %{}, "A"},
                 {:punctuation, %{}, "||"},
                 {:name, %{}, "A"},
                 {:operator, %{}, "<-"},
                 {:name, %{}, "B"},
                 {:punctuation, %{}, ","},
                 {:string_symbol, %{}, "true"},
                 {:punctuation, %{group_id: "group-1"}, "]"}
               ]
    end

    test "binary" do
      assert lex("[A||A<=B]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<="},
               {:name, %{}, "B"},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]

      assert lex("<<A||A<=B,true>>") == [
               {:punctuation, %{group_id: "group-1"}, "<<"},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<="},
               {:name, %{}, "B"},
               {:punctuation, %{}, ","},
               {:string_symbol, %{}, "true"},
               {:punctuation, %{group_id: "group-1"}, ">>"}
             ]
    end

    test "strict" do
      assert lex("[A||A<:-B]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<:-"},
               {:name, %{}, "B"},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]

      assert lex("[A||A<:=B]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<:="},
               {:name, %{}, "B"},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]
    end

    test "parallel" do
      assert lex("[A||A<-B&&C<-D]") == [
               {:punctuation, %{group_id: "group-1"}, "["},
               {:name, %{}, "A"},
               {:punctuation, %{}, "||"},
               {:name, %{}, "A"},
               {:operator, %{}, "<-"},
               {:name, %{}, "B"},
               {:punctuation, %{}, "&&"},
               {:name, %{}, "C"},
               {:operator, %{}, "<-"},
               {:name, %{}, "D"},
               {:punctuation, %{group_id: "group-1"}, "]"}
             ]
    end
  end

  describe "atoms" do
    test "are tokenized as such" do
      assert lex("atom") == [{:string_symbol, %{}, "atom"}]
      assert lex("at_om") == [{:string_symbol, %{}, "at_om"}]
      assert lex("atom@atom") == [{:string_symbol, %{}, "atom@atom"}]
    end

    test "are tokenized as such even when quoted" do
      assert lex("'atom'") == [{:string_symbol, %{}, "'atom'"}]
      assert lex("'atom atom'") == [{:string_symbol, %{}, "'atom atom'"}]
      assert lex("'atom+atom'") == [{:string_symbol, %{}, "'atom+atom'"}]
      assert lex("'atom@atom'") == [{:string_symbol, %{}, "'atom@atom'"}]
      assert lex("'atom123atom'") == [{:string_symbol, %{}, "'atom123atom'"}]
    end

    test "are tokenized when quoted and have escaped characters" do
      assert [{:string_symbol, %{}, ~s/'\\'escaped\\' quoted atom'/}] ==
               lex(~s/'\\'escaped\\' quoted atom'/)

      assert [{:string_symbol, %{}, ~s/'escaped \\b quote'/}] == lex(~s/'escaped \\b quote'/)

      assert {:string_symbol, %{}, ~s/'\\'escaped\\' quoted atom/} not in lex(
               ~s/'\\'invalid\\' quoted atom case/
             )
    end

    test "does not tokenize invalid characters as atom (\\n, ', \\)" do
      assert {:string_symbol, %{}, "atom"} in lex("atom\n")
      assert {:string_symbol, %{}, "atom"} in lex("atom'")
      assert {:string_symbol, %{}, "atom"} in lex("atom\\")
    end
  end

  describe "keywords" do
    test "keyword is tokenized as keyword" do
      assert lex("after") == [{:keyword, %{}, "after"}]
      assert lex("begin") == [{:keyword, %{}, "begin"}]
      assert lex("case") == [{:keyword, %{}, "case"}]
      assert lex("catch") == [{:keyword, %{}, "catch"}]
      assert lex("cond") == [{:keyword, %{}, "cond"}]
      assert lex("end") == [{:keyword, %{}, "end"}]
      assert lex("fun") == [{:keyword, %{}, "fun"}]
      assert lex("if") == [{:keyword, %{}, "if"}]
      assert lex("of") == [{:keyword, %{}, "of"}]
      assert lex("query") == [{:keyword, %{}, "query"}]
      assert lex("receive") == [{:keyword, %{}, "receive"}]
      assert lex("when") == [{:keyword, %{}, "when"}]
      assert lex("maybe") == [{:keyword, %{}, "maybe"}]
      assert lex("else") == [{:keyword, %{}, "else"}]
    end

    test "atoms are not tokenized as keyword" do
      refute lex("literal_atom") == [{:keyword, %{}, "literal_atom"}]
    end

    test "atoms that include a keyword on it is not tokenized as keyword" do
      refute {:keyword, %{}, "fun"} in lex("func")
      refute {:keyword, %{}, "when"} in lex("when_found")
      refute {:keyword, %{}, "when"} in lex("found_when")
    end
  end

  describe "operators" do
    test "syntax operators are tokenized as operator" do
      assert lex("+") == [{:operator, %{}, "+"}]
      assert lex("-") == [{:operator, %{}, "-"}]
      assert lex("*") == [{:operator, %{}, "*"}]
      assert lex("/") == [{:operator, %{}, "/"}]
      assert lex("==") == [{:operator, %{}, "=="}]
      assert lex("/=") == [{:operator, %{}, "/="}]
      assert lex("=:=") == [{:operator, %{}, "=:="}]
      assert lex("=/=") == [{:operator, %{}, "=/="}]
      assert lex("<") == [{:operator, %{}, "<"}]
      assert lex("=<") == [{:operator, %{}, "=<"}]
      assert lex(">") == [{:operator, %{}, ">"}]
      assert lex(">=") == [{:operator, %{}, ">="}]
      assert lex("++") == [{:operator, %{}, "++"}]
      assert lex("--") == [{:operator, %{}, "--"}]
      assert lex("=") == [{:operator, %{}, "="}]
      assert lex("!") == [{:operator, %{}, "!"}]
      assert lex("<-") == [{:operator, %{}, "<-"}]
      assert lex("<:-") == [{:operator, %{}, "<:-"}]
      assert lex("<=") == [{:operator, %{}, "<="}]
      assert lex("<:=") == [{:operator, %{}, "<:="}]
      assert lex("?=") == [{:operator, %{}, "?="}]
    end

    test "word operators are tokenized as operator" do
      assert lex("div") == [{:operator_word, %{}, "div"}]
      assert lex("rem") == [{:operator_word, %{}, "rem"}]
      assert lex("or") == [{:operator_word, %{}, "or"}]
      assert lex("xor") == [{:operator_word, %{}, "xor"}]
      assert lex("bor") == [{:operator_word, %{}, "bor"}]
      assert lex("bxor") == [{:operator_word, %{}, "bxor"}]
      assert lex("bsl") == [{:operator_word, %{}, "bsl"}]
      assert lex("bsr") == [{:operator_word, %{}, "bsr"}]
      assert lex("and") == [{:operator_word, %{}, "and"}]
      assert lex("band") == [{:operator_word, %{}, "band"}]
      assert lex("not") == [{:operator_word, %{}, "not"}]
      assert lex("bnot") == [{:operator_word, %{}, "bnot"}]
    end

    test "atoms are not tokenized as operator" do
      refute lex("literal_atom") == [{:operator_word, %{}, "literal_atom"}]
    end

    test "atoms that includes operators are not tokenized as operator" do
      refute {:operator_word, %{}, "div"} in lex("divatom")
      refute {:operator_word, %{}, "div"} in lex("div_atom")
      refute {:operator_word, %{}, "div"} in lex("atom_div")
      refute {:operator_word, %{}, "div"} in lex("atomdiv")
      refute {:operator_word, %{}, "div"} in lex("atomdivatom")
      refute {:operator_word, %{}, "div"} in lex("'div'")
      refute {:operator_word, %{}, "+"} in lex("'quoted + atom'")
    end

    test "string that includes operators are not tokenized as operator" do
      refute {:word_operator, %{}, "div"} in lex(~s/"div"/)
    end
  end

  describe "module attributes" do
    test "tokenizes definition of module attributtes" do
      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "module"} | _] =
               lex("-module(module_name).")

      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "export"} | _] =
               lex("-export([func/0]).")

      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "record"} | _] =
               lex(~s/-record(module_name, {name = "", id})./)
    end

    test "tokenizes the value of a module attribute" do
      tokens = lex(~s/-record(module_name, {name = "", id})./)
      assert {:name_attribute, %{}, "record"} in tokens
      assert {:string_symbol, %{}, "module_name"} in tokens
      assert {:string_symbol, %{}, "id"} in tokens
    end

    test "tokenizes module attributes when incomplete" do
      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "module"} | _] =
               lex("-module(module_")

      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "export"} | _] =
               lex("-export([func/")

      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "record"} | _] =
               lex(~s"-record(module_name, {name =")
    end

    test "tokenizes module attributes with whitespace" do
      assert [
               {:punctuation, %{}, "-"},
               {:whitespace, %{}, " "},
               {:name_attribute, %{}, "module"} | _
             ] = lex("- module(module_name).")

      assert [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "module"} | _] =
               lex("-module (module_name).")

      assert [
               {:punctuation, %{}, "-"},
               {:whitespace, %{}, " "},
               {:name_attribute, %{}, "module"},
               {:whitespace, %{}, " "} | _
             ] = lex("- module (module_name).")
    end

    test "matches module attributes that start with a newline" do
      assert [
               {:whitespace, %{}, "\n"},
               {:punctuation, %{}, "-"},
               {:name_attribute, %{}, "module"} | _
             ] = lex("\n-module(module_name).")
    end

    test "does not tokenize function calls as module attributes" do
      assert {:name_function, %{}, "b"} in lex("a(X) - b(Y)")
      assert {:name_attribute, %{}, "b"} not in lex("a(X) - b(Y)")
    end

    test "handles -spec attributes" do
      [{:punctuation, %{}, "-"}, {:name_attribute, %{}, "spec"} | _] =
        lex("-spec function_name(type(), type()) -> type().")
    end
  end

  describe "record" do
    test "tokenizes full record definitions correctly" do
      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "record"},
               {:punctuation, %{}, "{"} | _
             ] = lex("#record{attribute = Value}.")

      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "record"},
               {:punctuation, %{}, "{"} | _
             ] = lex("#record{attribute = Value, other_attribute = OtherValue}.")

      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "record"},
               {:punctuation, %{}, "{"} | _
             ] = lex("#record{}.")
    end

    test "tokenizes record attribute access correctly" do
      assert [
               {_, %{}, "RecordVariable"},
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "record_name"},
               {:punctuation, %{}, "."} | _
             ] = lex("RecordVariable#record_name.attribute")
    end

    test "tokenizes the update of a record correctly" do
      assert [
               {_, %{}, "RecordVariable"},
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "record_name"},
               {:punctuation, %{}, "{"} | _
             ] = lex("RecordVariable#record_name{attribute = Value")
    end

    test "does not tokenize invalid records" do
      tokens = lex("#record(attribute = Value)")
      assert {:operator, %{}, "#"} not in tokens
      assert {:string_symbol, %{}, "record"} not in tokens
    end
  end

  describe "maybe expression" do
    # `?=` is the maybe-expression match operator added in OTP 25.
    test "tokenizes ?= as a single operator inside a maybe block" do
      assert lex("maybe X ?= ok end") == [
               {:keyword, %{}, "maybe"},
               {:whitespace, %{}, " "},
               {:name, %{}, "X"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "?="},
               {:whitespace, %{}, " "},
               {:string_symbol, %{}, "ok"},
               {:whitespace, %{}, " "},
               {:keyword, %{}, "end"}
             ]
    end
  end

  describe "builtin (BIF) recognition" do
    # The @builtins list is generated at compile time from `erl_internal:bif/2`.
    test "atoms that are auto-imported BIFs render as :name_builtin" do
      assert [{:name_builtin, %{}, "length"}] = lex("length")
      assert [{:name_builtin, %{}, "tuple_size"}] = lex("tuple_size")
    end

    test "BIF calls (`name(...)`) render as :name_builtin not :name_function" do
      # makeup_erlang #13. Before this fix, `length(L)` rendered as a regular
      # function call instead of a builtin.
      assert [{:name_builtin, %{}, "length"} | _] = lex("length(L)")
      assert [{:name_builtin, %{}, "is_atom"} | _] = lex("is_atom(X)")
      assert [{:name_builtin, %{}, "tuple_size"} | _] = lex("tuple_size(T)")
    end

    test "post-OTP-19 BIFs are recognised (proves the static list is gone)" do
      assert [{:name_builtin, %{}, "map_get"} | _] = lex("map_get(K, M)")
      assert [{:name_builtin, %{}, "is_map_key"} | _] = lex("is_map_key(K, M)")
      assert [{:name_builtin, %{}, "binary_part"} | _] = lex("binary_part(B, 0, 4)")
      assert [{:name_builtin, %{}, "floor"} | _] = lex("floor(X)")
      assert [{:name_builtin, %{}, "ceil"} | _] = lex("ceil(X)")
    end

    test "module_info and nif_error are not classified as BIFs" do
      # Both are exported from `erlang` but neither is auto-imported.
      refute Enum.any?(lex("module_info"), &match?({:name_builtin, _, "module_info"}, &1))
      refute Enum.any?(lex("nif_error"), &match?({:name_builtin, _, "nif_error"}, &1))
    end
  end

  describe "fun keyword vs function call" do
    test "fun(X) -> ... end tokenizes `fun` as keyword, not function name" do
      assert [
               {:keyword, %{}, "fun"},
               {:punctuation, _, "("},
               {:name, %{}, "X"},
               {:punctuation, _, ")"} | _
             ] = lex("fun(X) -> X end")
    end

    test "fun mod:func/2 still tokenizes correctly" do
      assert [
               {:keyword, %{}, "fun"},
               {:whitespace, %{}, " "},
               {:name_class, %{}, "mod"},
               {:punctuation, %{}, ":"},
               {:string_symbol, %{}, "func"},
               {:punctuation, %{}, "/"},
               {:number_integer, %{}, "2"}
             ] = lex("fun mod:func/2")
    end
  end

  describe "OTP-current module attribute coverage" do
    # The generic `module_attribute` rule accepts any `atom_name`, which
    # means new attributes ship without lexer changes. Lock the current
    # OTP-supported set with an explicit assertion list so the rule
    # keeps covering them.
    @known_attributes ~w[module export import behaviour behavior callback
                         optional_callbacks on_load nifs deprecated removed
                         feature compile export_type record export_record
                         import_record spec type opaque doc moduledoc define
                         ifdef ifndef else endif if elif vsn]

    test "every current OTP module attribute lexes as :name_attribute" do
      for attr <- @known_attributes do
        # Use `(Body)` so the body is one well-known token. The point of
        # the test is the attribute name, not the body shape.
        expected = [
          {:whitespace, %{}, "\n"},
          {:punctuation, %{}, "-"},
          {:name_attribute, %{}, attr},
          {:punctuation, %{group_id: "group-1"}, "("},
          {:name, %{}, "Body"},
          {:punctuation, %{group_id: "group-1"}, ")"}
        ]

        actual = lex("\n-" <> attr <> "(Body)")

        assert actual == expected,
               "expected -#{attr} to lex as :name_attribute\n" <>
                 "expected: #{inspect(expected)}\n" <>
                 "actual:   #{inspect(actual)}"
      end
    end
  end

  describe "native records (OTP 29)" do
    test "tokenizes external native record construction" do
      assert [
               {:operator, %{}, "#"},
               {:name_class, %{}, "vector_lib"},
               {:punctuation, %{}, ":"},
               {:string_symbol, %{}, "vector"},
               {:punctuation, %{}, "{"} | _
             ] = lex("#vector_lib:vector{x = 1.0, y = 2.0}")
    end

    test "tokenizes external native record print form" do
      assert [
               {:operator, %{}, "#"},
               {:name_class, %{}, "example"},
               {:punctuation, %{}, ":"},
               {:string_symbol, %{}, "pair"},
               {:punctuation, %{}, "{"} | _
             ] = lex("#example:pair{a = 1, b = 2}")
    end

    test "tokenizes external native record field access" do
      assert [
               {_, %{}, "X"},
               {:operator, %{}, "#"},
               {:name_class, %{}, "vector_lib"},
               {:punctuation, %{}, ":"},
               {:string_symbol, %{}, "vector"},
               {:punctuation, %{}, "."} | _
             ] = lex("X#vector_lib:vector.x")
    end

    test "tokenizes local native record construction the same as tuple-based records" do
      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "pair"},
               {:punctuation, %{}, "{"} | _
             ] = lex("#pair{a = 1, b = 2}")
    end

    test "tokenizes -record #Name{...} native definition attribute" do
      tokens = lex("\n-record #pair{a, b}.")
      assert {:name_attribute, %{}, "record"} in tokens
      assert {:operator, %{}, "#"} in tokens
      assert {:string_symbol, %{}, "pair"} in tokens
    end

    test "tokenizes -export_record attribute" do
      assert [
               {:whitespace, %{}, "\n"},
               {:punctuation, %{}, "-"},
               {:name_attribute, %{}, "export_record"} | _
             ] = lex("\n-export_record([vector, position]).")
    end

    test "tokenizes -import_record attribute" do
      assert [
               {:whitespace, %{}, "\n"},
               {:punctuation, %{}, "-"},
               {:name_attribute, %{}, "import_record"} | _
             ] = lex("\n-import_record(vector_lib, [vector, position]).")
    end

    test "does not break the existing local-record rule when there is no `:`" do
      tokens = lex("X#name{f = 1}")
      assert {:operator, %{}, "#"} in tokens
      assert {:string_symbol, %{}, "name"} in tokens
      refute Enum.any?(tokens, fn t -> match?({:name_class, _, _}, t) end)
    end

    test "external native record pattern match" do
      assert [
               {:operator, %{}, "#"},
               {:name_class, %{}, "mod"},
               {:punctuation, %{}, ":"},
               {:string_symbol, %{}, "name"},
               {:punctuation, _, "{"},
               {:string_symbol, %{}, "f"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "="},
               {:whitespace, %{}, " "},
               {:name, %{}, "X"},
               {:punctuation, _, "}"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "="},
               {:whitespace, %{}, " "},
               {:name, %{}, "Y"}
             ] = lex("#mod:name{f = X} = Y")
    end

    test "external native record update via prefixed variable" do
      assert [
               {:name, %{}, "Y"},
               {:operator, %{}, "#"},
               {:name_class, %{}, "mod"},
               {:punctuation, %{}, ":"},
               {:string_symbol, %{}, "name"},
               {:punctuation, _, "{"} | _
             ] = lex("Y#mod:name{f = 2}")
    end

    # Native records relax the record-name rule:
    # https://www.erlang.org/doc/system/data_types.html says "it is not
    # necessary to quote atoms that look like variable names or keywords."
    # So `#State{}`, `#div{}`, `#case{}` are all valid.
    test "variable-shape name (`#State{}`)" do
      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "State"},
               {:punctuation, _, "{"},
               {:string_symbol, %{}, "x"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "="},
               {:whitespace, %{}, " "},
               {:number_integer, %{}, "1"},
               {:punctuation, _, "}"}
             ] = lex("#State{x = 1}")
    end

    test "external native record with variable-shape name" do
      assert [
               {:operator, %{}, "#"},
               {:name_class, %{}, "mod"},
               {:punctuation, %{}, ":"},
               {:string_symbol, %{}, "State"},
               {:punctuation, _, "{"} | _
             ] = lex("#mod:State{x = 1}")
    end

    # Keyword and word-operator names stay as `:string_symbol` in record
    # position. Postprocess sees the `record_name: true` meta marker and
    # skips the usual conversion to `:keyword` / `:operator_word`, so the
    # surrounding `#...{` shape renders consistently regardless of whether
    # the name happens to be a reserved word.
    test "keyword name (`#case{}`) stays as :string_symbol" do
      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "case"},
               {:punctuation, _, "{"} | _
             ] = lex("#case{x = 1}")
    end

    test "keyword name (`#fun{}`)" do
      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "fun"},
               {:punctuation, _, "{"} | _
             ] = lex("#fun{f = g}")
    end

    test "word-operator name (`#div{}`)" do
      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "div"},
               {:punctuation, _, "{"} | _
             ] = lex("#div{class}")
    end

    test "external native record with keyword name (`#mod:case{}`)" do
      assert [
               {:operator, %{}, "#"},
               {:name_class, %{}, "mod"},
               {:punctuation, %{}, ":"},
               {:string_symbol, %{}, "case"},
               {:punctuation, _, "{"} | _
             ] = lex("#mod:case{x = 1}")
    end

    test "quoted-atom record name (`#'42'{}`)" do
      assert [
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "'42'"},
               {:punctuation, _, "{"} | _
             ] = lex("#'42'{}")
    end

    # Declaration syntax: `-record #Name{...}.` (no parens around the name).
    # This is the OTP 29 native-record definition form, distinct from the
    # tuple-based `-record(name, {...}).` form. The same name flexibility
    # (lowercase / variable-shape / keyword / quoted) applies.
    test "definition with lowercase name" do
      assert lex("\n-record #pair{a, b}.") == [
               {:whitespace, %{}, "\n"},
               {:punctuation, %{}, "-"},
               {:name_attribute, %{}, "record"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "pair"},
               {:punctuation, %{group_id: "group-1"}, "{"},
               {:string_symbol, %{}, "a"},
               {:punctuation, %{}, ","},
               {:whitespace, %{}, " "},
               {:string_symbol, %{}, "b"},
               {:punctuation, %{group_id: "group-1"}, "}"},
               {:punctuation, %{}, "."}
             ]
    end

    test "definition with variable-shape name (`-record #State{x}.`)" do
      assert lex("\n-record #State{x}.") == [
               {:whitespace, %{}, "\n"},
               {:punctuation, %{}, "-"},
               {:name_attribute, %{}, "record"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "State"},
               {:punctuation, %{group_id: "group-1"}, "{"},
               {:string_symbol, %{}, "x"},
               {:punctuation, %{group_id: "group-1"}, "}"},
               {:punctuation, %{}, "."}
             ]
    end

    test "definition with keyword name (`-record #div{class}.`)" do
      assert lex("\n-record #div{class}.") == [
               {:whitespace, %{}, "\n"},
               {:punctuation, %{}, "-"},
               {:name_attribute, %{}, "record"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "div"},
               {:punctuation, %{group_id: "group-1"}, "{"},
               {:string_symbol, %{}, "class"},
               {:punctuation, %{group_id: "group-1"}, "}"},
               {:punctuation, %{}, "."}
             ]
    end

    test "definition with quoted name (`-record #'42'{}.`)" do
      assert lex("\n-record #'42'{}.") == [
               {:whitespace, %{}, "\n"},
               {:punctuation, %{}, "-"},
               {:name_attribute, %{}, "record"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "'42'"},
               {:punctuation, %{group_id: "group-1"}, "{"},
               {:punctuation, %{group_id: "group-1"}, "}"},
               {:punctuation, %{}, "."}
             ]
    end

    test "the record_name meta marker does not leak into output tokens" do
      # Postprocess strips the marker after acting on it. End-to-end the
      # token's meta should be the same as for any other :string_symbol.
      [_, {:string_symbol, meta_kw, "case"} | _] = lex("#case{x = 1}")
      [_, {:string_symbol, meta_lc, "vector"} | _] = lex("#vector{x = 1}")
      assert meta_kw == meta_lc
      refute Map.has_key?(meta_kw, :record_name)
    end

    test "definition with default values" do
      # `-record #vector{x = 0.0, y = 0.0}.` — the OTP 29 spec example.
      assert lex("\n-record #vector{x = 0.0, y = 0.0}.") == [
               {:whitespace, %{}, "\n"},
               {:punctuation, %{}, "-"},
               {:name_attribute, %{}, "record"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "#"},
               {:string_symbol, %{}, "vector"},
               {:punctuation, %{group_id: "group-1"}, "{"},
               {:string_symbol, %{}, "x"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "="},
               {:whitespace, %{}, " "},
               {:number_float, %{}, "0.0"},
               {:punctuation, %{}, ","},
               {:whitespace, %{}, " "},
               {:string_symbol, %{}, "y"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "="},
               {:whitespace, %{}, " "},
               {:number_float, %{}, "0.0"},
               {:punctuation, %{group_id: "group-1"}, "}"},
               {:punctuation, %{}, "."}
             ]
    end
  end

  describe "function_arity" do
    test "is tokenized correctly for the syntax function_name/arity" do
      assert [
               {:string_symbol, %{}, "function_name"},
               {:punctuation, %{}, "/"},
               {:number_integer, %{}, "0"}
             ] == lex("function_name/0")
    end

    test "is tokenized correctly when referenced with `fun function_name/arity`" do
      tokens = lex("function_name/0")
      assert {:string_symbol, %{}, "function_name"} in tokens
      assert {:punctuation, %{}, "/"} in tokens
      assert {:number_integer, %{}, "0"} in tokens
    end
  end

  describe "prompt" do
    test "without number" do
      assert lex("> a.") == [
               {:generic_prompt, %{selectable: false}, "> "},
               {:string_symbol, %{}, "a"},
               {:punctuation, %{}, "."}
             ]

      assert lex("(a@b)> a.") == [
               {:generic_prompt, %{selectable: false}, "(a@b)> "},
               {:string_symbol, %{}, "a"},
               {:punctuation, %{}, "."}
             ]
    end

    test "with number" do
      assert lex("1> a.") == [
               {:generic_prompt, %{selectable: false}, "1> "},
               {:string_symbol, %{}, "a"},
               {:punctuation, %{}, "."}
             ]

      assert lex("(a@b)1> a.") == [
               {:generic_prompt, %{selectable: false}, "(a@b)1> "},
               {:string_symbol, %{}, "a"},
               {:punctuation, %{}, "."}
             ]
    end

    test "greater-than still works" do
      assert lex("1>2") == [
               {:number_integer, %{}, "1"},
               {:operator, %{}, ">"},
               {:number_integer, %{}, "2"}
             ]

      assert lex("1 > 2") == [
               {:number_integer, %{}, "1"},
               {:whitespace, %{}, " "},
               {:operator, %{}, ">"},
               {:whitespace, %{}, " "},
               {:number_integer, %{}, "2"}
             ]
    end

    # makeup_elixir #28 analogue. The whitespace rule used to consume
    # multi-line whitespace blocks greedily, leaving no `\n` for the prompt
    # rule to anchor against. The prompt rule now matches any leading
    # whitespace block that contains a `\n`.
    test "is detected after a multi-line whitespace block" do
      assert [
               {:whitespace, %{}, "\n  \n"},
               {:generic_prompt, %{selectable: false}, "1> "},
               {:string_symbol, %{}, "ok"},
               {:punctuation, %{}, "."}
             ] = lex("\n  \n1> ok.")
    end

    test "with newlines" do
      assert lex("x. 1> a.") == [
               {:string_symbol, %{}, "x"},
               {:punctuation, %{}, "."},
               {:whitespace, %{}, " "},
               {:number_integer, %{}, "1"},
               {:operator, %{}, ">"},
               {:whitespace, %{}, " "},
               {:string_symbol, %{}, "a"},
               {:punctuation, %{}, "."}
             ]

      assert lex("x\n1> y") == [
               {:string_symbol, %{}, "x"},
               {:whitespace, %{}, "\n"},
               {:generic_prompt, %{selectable: false}, "1> "},
               {:string_symbol, %{}, "y"}
             ]

      assert lex("x \n1> y") == [
               {:string_symbol, %{}, "x"},
               {:whitespace, %{}, " \n"},
               {:generic_prompt, %{selectable: false}, "1> "},
               {:string_symbol, %{}, "y"}
             ]

      assert lex("x\r\n1> y") == [
               {:string_symbol, %{}, "x"},
               {:whitespace, %{}, "\r\n"},
               {:generic_prompt, %{selectable: false}, "1> "},
               {:string_symbol, %{}, "y"}
             ]

      assert lex("x \r\n1> y") == [
               {:string_symbol, %{}, "x"},
               {:whitespace, %{}, " \r\n"},
               {:generic_prompt, %{selectable: false}, "1> "},
               {:string_symbol, %{}, "y"}
             ]
    end
  end

  describe "shell error" do
    test "single asterix" do
      assert lex("1> P.\n* 1:1: variable 'P' is unbound") == [
               {:generic_prompt, %{selectable: false}, "1> "},
               {:name, %{}, "P"},
               {:punctuation, %{}, "."},
               {:whitespace, %{}, "\n"},
               {:generic_traceback, %{}, "* 1:1: variable 'P' is unbound"}
             ]
    end

    test "double asterix aka multiline error" do
      assert lex(
               "1> P = Descriptor.\n** exception error: no match of right hand side value {4,abcd}"
             ) == [
               {:generic_prompt, %{selectable: false}, "1> "},
               {:name, %{}, "P"},
               {:whitespace, %{}, " "},
               {:operator, %{}, "="},
               {:whitespace, %{}, " "},
               {:name, %{}, "Descriptor"},
               {:punctuation, %{}, "."},
               {:whitespace, %{}, "\n"},
               {:generic_traceback, %{},
                "** exception error: no match of right hand side value {4,abcd}"}
             ]

      assert lex(~S"""
             1> list_to_binary(<<>>).
             ** exception error: bad argument
                  in function  list_to_binary/1
                     called as list_to_binary(<<>>)
                     *** argument 1: not an iolist term
             """) == [
               {:generic_prompt, %{selectable: false}, "1> "},
               {:name_builtin, %{}, "list_to_binary"},
               {:punctuation, %{group_id: "group-1"}, "("},
               {:punctuation, %{group_id: "group-2"}, "<<"},
               {:punctuation, %{group_id: "group-2"}, ">>"},
               {:punctuation, %{group_id: "group-1"}, ")"},
               {:punctuation, %{}, "."},
               {:whitespace, %{}, "\n"},
               {
                 :generic_traceback,
                 %{},
                 "** exception error: bad argument\n     in function  list_to_binary/1\n        called as list_to_binary(<<>>)\n        *** argument 1: not an iolist term"
               },
               {:whitespace, %{}, "\n"}
             ]
    end
  end
end
