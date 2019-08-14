defmodule Makeup.Lexers.ErlangLexer.ApplicationTest do
  use ExUnit.Case, async: true

  alias Makeup.Registry
  alias Makeup.Lexers.ErlangLexer

  describe "start/2" do
    test "registers itself as an `makeup` lexer on application boot for `erlang` and `erl` language names" do
      assert {:ok, {ErlangLexer, []}} == Registry.fetch_lexer_by_name("erlang")
      assert {:ok, {ErlangLexer, []}} == Registry.fetch_lexer_by_name("erl")
    end

    test "registers itself as an `makeup` lexer on application boot for `erl`, `hrl` and `escript` file extensions" do
      assert {:ok, {ErlangLexer, []}} == Registry.fetch_lexer_by_extension("erl")
      assert {:ok, {ErlangLexer, []}} == Registry.fetch_lexer_by_extension("hrl")
      assert {:ok, {ErlangLexer, []}} == Registry.fetch_lexer_by_extension("escript")
    end
  end
end
