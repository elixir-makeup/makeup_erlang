defmodule ErlangLexerTokenizer do
  use ExUnit.Case, async: false
  import Makeup.Lexers.ErlangLexer.Testing, only: [lex: 1]

  test "empty string" do
    assert lex("") == []
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
      assert [{:string, %{}, ~s/"escape \\"double quote\\""/}] == lex(~s/"escape \\"double quote\\""/)
      assert [{:string, %{}, ~s/"\\"quote\\""/}] == lex(~s/"\\"quote\\""/)
      assert {:string, %{}, ~s/"invalid string\\"/} not in lex(~s/"invalid string\\"/)
    end
    
    test "tokenizes literal escaped characters correctly" do
      assert [{:string, %{}, ~s/"\\b"/}] == lex(~s/"\\b"/)
      assert [{:string, %{}, ~s/"\\\\b"/}] == lex(~s/"\\\\b"/)
    end
  end

  describe "binary" do
    test "<<>> syntax" do
      assert lex(~s/<<>>/) == [{:punctuation, %{}, "<<"}, {:punctuation, %{}, ">>"}]
    end

    test "<<\"\">> syntax" do
      assert lex(~s/<<"">>/) == [
               {:punctuation, %{}, "<<"},
               {:string, %{}, ~s/""/},
               {:punctuation, %{}, ">>"}
             ]
    end

    test "<<\"string\">> syntax" do
      assert lex(~s/<<"string">>/) == [
               {:punctuation, %{}, "<<"},
               {:string, %{}, ~s/"string"/},
               {:punctuation, %{}, ">>"}
             ]
    end
  end

  describe "atoms" do
    test "are tokenized as such" do
      assert lex("atom") == [{:string_symbol, %{}, "atom"}]
    end

    test "are tokenized as such even when quoted" do
      assert lex("'atom'") == [{:string_symbol, %{}, "'atom'"}]
      assert lex("'atom atom'") == [{:string_symbol, %{}, "'atom atom'"}]
      assert lex("'atom+atom'") == [{:string_symbol, %{}, "'atom+atom'"}]
      assert lex("'atom@atom'") == [{:string_symbol, %{}, "'atom@atom'"}]
      assert lex("'atom123atom'") == [{:string_symbol, %{}, "'atom123atom'"}]
    end
    
    test "are tokenized when quoted and have escaped characters" do
      assert [{:string_symbol, %{}, ~s/'\\'escaped\\' quoted atom'/}] == lex(~s/'\\'escaped\\' quoted atom'/)
      assert [{:string_symbol, %{}, ~s/'escaped \\b quote'/}] == lex(~s/'escaped \\b quote'/)
      assert {:string_symbol, %{}, ~s/'\\'escaped\\' quoted atom/} not in lex(~s/'\\'invalid\\' quoted atom case/)
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
end
