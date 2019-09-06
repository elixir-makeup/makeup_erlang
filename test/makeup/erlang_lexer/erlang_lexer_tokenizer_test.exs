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
             {:name_namespace, %{}, "mod"},
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
             {:name_namespace, %{}, "mod"},
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

  describe "binary" do
    test "<<>> syntax" do
      assert lex(~s/<<>>/) == [{:punctuation, %{}, "<<"}, {:punctuation, %{}, ">>"}]
    end

    test "<<\"\">> syntax" do
      assert lex(~s/<<"">>/) == [
               {:punctuation, %{}, "<<"},
               {:punctuation, %{}, "\""},
               {:punctuation, %{}, "\""},
               {:punctuation, %{}, ">>"}
             ]
    end

    test "<<\"string\">> syntax" do
      assert lex(~s/<<"string">>/) == [
               {:punctuation, %{}, "<<"},
               {:punctuation, %{}, "\""},
               {:string_symbol, %{}, "string"},
               {:punctuation, %{}, "\""},
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
end
