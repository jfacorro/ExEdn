defmodule Eden.LexerTest do
  use ExUnit.Case
  import Eden.Lexer
  alias Eden.Lexer
  alias Eden.Exception, as: Ex

  test "Whitespace" do
    assert tokenize(",,,  ") == []
    assert tokenize(" \n \t, \r") == []

    assert_raise Ex.UnexpectedInputError, fn ->
      tokenize(" \n \t, \r a| ,,,")
    end
  end

  test "nil, true, false" do
    assert tokenize("nil") == [token(nil, "nil")]
    assert tokenize(" nil ") == [token(nil, "nil")]
    assert tokenize("true") == [token(true, "true")]
    assert tokenize(" true ") == [token(true, "true")]
    assert tokenize("false") == [token(false, "false")]
    assert tokenize(" false ") == [token(false, "false")]

    assert List.first(tokenize(" nil{ ")) == token(nil, "nil")
    assert List.first(tokenize(" nilo ")) == token(:symbol, "nilo")

    assert List.first(tokenize(" true} ")) == token(true, "true")
    assert List.first(tokenize(" truedetective ")) == token(:symbol, "truedetective")

    assert List.first(tokenize(" false{ ")) == token(false, "false")
    assert List.first(tokenize(" falsette ")) == token(:symbol, "falsette")
  end

  test "String" do
    assert tokenize(" \"this is a string\" ") == [token(:string, "this is a string")]
    assert tokenize(" \"this is a \\\" string\" ") == [token(:string, "this is a \" string")]

    assert_raise Ex.UnfinishedTokenError, fn ->
      tokenize(" \"this is an unfinished string ")
    end

    assert_raise Ex.UnfinishedTokenError, fn ->
      tokenize(" \"this is an unfinished string\\\"")
    end
  end

  test "Character" do
    assert tokenize(" \\t ") == [token(:character, "t")]
    assert tokenize(" \\r,, ") == [token(:character, "r")]
  end

  test "Keyword" do
    assert tokenize(" :a-keyword ") == [token(:keyword, "a-keyword")]
    assert tokenize(":a-keyword") == [token(:keyword, "a-keyword")]
    assert tokenize(" :question? ") == [token(:keyword, "question?")]
    assert tokenize(":question?{") == [token(:keyword, "question?"), token(:curly_open, "{")]
    assert tokenize(":k?+._-!7><$&=*") == [token(:keyword, "k?+._-!7><$&=*")]

    assert_raise Ex.UnexpectedInputError, fn ->
      tokenize(" :question?\\")
    end
  end

  test "Symbol" do
    assert tokenize(" a-keyword ") == [token(:symbol, "a-keyword")]
    assert tokenize("a-keyword") == [token(:symbol, "a-keyword")]
    assert tokenize(" question? ") == [token(:symbol, "question?")]
    assert tokenize("question?{") == [token(:symbol, "question?"), token(:curly_open, "{")]
    assert tokenize("k?+._-!7><$&=*") == [token(:symbol, "k?+._-!7><$&=*")]
    assert tokenize("ns/name") == [token(:symbol, "ns/name")]

    assert_raise Ex.UnexpectedInputError, fn ->
      tokenize(" question?\\")
    end

    assert_raise Ex.UnexpectedInputError, fn ->
      tokenize("ns/name/ss")
    end
  end

  test "Integer" do
    assert tokenize("1234") == [token(:integer, "1234")]
    assert tokenize("-1234") == [token(:integer, "-1234")]
    assert tokenize("+1234") == [token(:integer, "+1234")]
    assert tokenize(" 1234 ") == [token(:integer, "1234")]
    assert tokenize("1234N") == [token(:integer, "1234N")]
    assert tokenize("1234N{") == [token(:integer, "1234N"), token(:curly_open, "{")]

    assert_raise Ex.UnexpectedInputError, fn ->
      assert tokenize("1234a")
    end
  end

  test "Float" do
    assert tokenize("1234.12") == [token(:float, "1234.12")]
    assert tokenize(" 1234.12 ") == [token(:float, "1234.12")]
    assert tokenize("1234M") == [token(:float, "1234M")]
    assert tokenize("1234M{") == [token(:float, "1234M"), token(:curly_open, "{")]

    assert tokenize("1234E12") == [token(:float, "1234E12")]
    assert tokenize("1234E-12") == [token(:float, "1234E-12")]
    assert tokenize("1234E+12") == [token(:float, "1234E+12")]

    assert tokenize("1234e12") == [token(:float, "1234e12")]
    assert tokenize("1234e-12") == [token(:float, "1234e-12")]
    assert tokenize("1234e+12") == [token(:float, "1234e+12")]

    assert_raise Ex.UnexpectedInputError, fn ->
      assert tokenize("1234.a")
    end

    assert_raise Ex.UnexpectedInputError, fn ->
      assert tokenize("1234.121a ")
    end

    assert_raise Ex.UnexpectedInputError, fn ->
      assert tokenize("1234E0a1")
    end

    assert_raise Ex.UnfinishedTokenError, fn ->
      tokenize("1234E")
    end

    assert_raise Ex.UnfinishedTokenError, fn ->
      tokenize("1234.")
    end

    assert_raise Ex.UnfinishedTokenError, fn ->
      tokenize("1234. :kw")
    end
  end

  test "Delimiters" do
    assert tokenize("{[#\{}]} )()") == [
             token(:curly_open, "{"),
             token(:bracket_open, "["),
             token(:set_open, "#\{"),
             token(:curly_close, "}"),
             token(:bracket_close, "]"),
             token(:curly_close, "}"),
             token(:paren_close, ")"),
             token(:paren_open, "("),
             token(:paren_close, ")")
           ]
  end

  test "Discard" do
    assert tokenize("#_ ") == [token(:discard, "#_")]

    assert tokenize("1 #_ :kw") == [
             token(:integer, "1"),
             token(:discard, "#_"),
             token(:keyword, "kw")
           ]
  end

  test "Tag" do
    assert tokenize("#ns/name") == [token(:tag, "ns/name")]
    assert tokenize("#whatever") == [token(:tag, "whatever")]
    assert tokenize(" #whatever :kw") == [token(:tag, "whatever"), token(:keyword, "kw")]
  end

  test "Comment" do
    assert tokenize("1 ;; hello") == [token(:integer, "1"), token(:comment, " hello")]
    assert tokenize("1 ;; hello\n\r") == [token(:integer, "1"), token(:comment, " hello")]

    assert tokenize("1 ;; hello\n\r bla") == [
             token(:integer, "1"),
             token(:comment, " hello"),
             token(:symbol, "bla")
           ]
  end

  test "Line and Column Information" do
    tokens = [
      token(:integer, "1", %{line: 1, col: 0}),
      token(:comment, " hello", %{line: 1, col: 2})
    ]

    assert tokenize("1 ;; hello", location: true) == tokens
    assert tokenize("1 ;; hello\r\n", location: true) == tokens

    tokens = [
      token(:integer, "1", %{line: 1, col: 0}),
      token(:comment, " hello", %{line: 1, col: 2}),
      token(:symbol, "bla", %{line: 2, col: 1})
    ]

    assert tokenize("1 ;; hello\r\n bla", location: true) == tokens
    assert tokenize("1 ;; hello\n\r bla", location: true) == tokens

    tokens = [
      token(:integer, "1", %{line: 1, col: 0}),
      token(:string, "hello \n world", %{line: 2, col: 0}),
      token(:keyword, "kw", %{line: 3, col: 8})
    ]

    assert tokenize("1 \n\"hello \n world\" :kw ", location: true) == tokens

    tokens = [
      token(:integer, "1", %{line: 1, col: 0}),
      token(:string, "hello \n \" world", %{line: 2, col: 0}),
      token(:keyword, "kw", %{line: 3, col: 1})
    ]

    assert tokenize("1 \n\"hello \\n \\\" world\"\n :kw ", location: true) == tokens
  end

  defp token(type, value, location \\ nil) do
    token = %Lexer.Token{type: type, value: value}

    if location,
      do: Map.put(token, :location, location),
      else: token
  end
end
