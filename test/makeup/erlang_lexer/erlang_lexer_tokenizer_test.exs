defmodule ErlangLexerTokenizer do
  use ExUnit.Case, async: false
  import AssertValue
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
               {:name_symbol, %{}, "string"},
               {:punctuation, %{}, "\""},
               {:punctuation, %{}, ">>"}
             ]
    end
  end
end
