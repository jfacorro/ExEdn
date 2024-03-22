defmodule Eden.ParserTest do
  use ExUnit.Case
  import Eden.Parser
  alias Eden.Parser
  alias Eden.Exception, as: Ex

  test "Whitespace" do
    assert parse(",,,  ") == node(:root, nil, [])
    assert parse(" \n \t, \r") == node(:root, nil, [])
  end

  test "Literals" do
    root = node(:root, nil, [node(nil, "nil"), node(true, "true"), node(false, "false")])
    assert parse("nil true false") == root

    root = node(:root, nil, [node(:integer, "1")])
    assert parse("1") == root
    root = node(:root, nil, [node(:integer, "29382329N")])
    assert parse("29382329N") == root

    root = node(:root, nil, [node(:float, "29382329M")])
    assert parse("29382329M") == root
    root = node(:root, nil, [node(:float, "1.33")])
    assert parse("1.33") == root

    root =
      node(:root, nil, [node(:symbol, "nilo"), node(:symbol, "truthy"), node(:symbol, "falsey")])

    assert parse("nilo truthy falsey") == root

    root =
      node(:root, nil, [node(:keyword, "nilo"), node(:string, "truthy"), node(:keyword, "falsey")])

    assert parse(":nilo \"truthy\" :falsey") == root

    root = node(:root, nil, [node(:character, "h"), node(:character, "i")])
    assert parse("\\h\\i") == root

    root = node(:root, nil, [node(:string, "Thaïlande")])
    assert parse("\"Thaïlande\"") == root

    assert_raise Ex.UnfinishedTokenError, fn ->
      parse(":")
    end

    assert_raise Ex.UnfinishedTokenError, fn ->
      parse(": :a")
    end
  end

  test "Map" do
    root = node(:root, nil, [node(:map, nil)])
    assert parse("{}") == root

    root = node(:root, nil, [node(:map, nil, [node(:keyword, "name"), node(:string, "John")])])
    assert parse("{:name \"John\"}") == root

    root =
      node(:root, nil, [
        node(:map, nil, [
          node(:keyword, "name"),
          node(:string, "John"),
          node(:keyword, "age"),
          node(:integer, "120")
        ])
      ])

    assert parse("{:name \"John\", :age 120}") == root

    assert_raise Ex.OddExpressionCountError, fn ->
      parse("{nil true false}")
    end

    assert_raise Ex.UnbalancedDelimiterError, fn ->
      parse("{nil true  ")
    end
  end

  test "Vector" do
    root = node(:root, nil, [node(:vector, nil)])
    assert parse("[]") == root

    root = node(:root, nil, [node(:vector, nil, [node(:keyword, "name"), node(:string, "John")])])
    assert parse("[:name, \"John\"]") == root

    root =
      node(:root, nil, [
        node(:vector, nil, [node(:keyword, "name"), node(:string, "John"), node(:integer, "120")])
      ])

    assert parse("[:name, \"John\", 120]") == root

    assert_raise Ex.UnbalancedDelimiterError, fn ->
      parse("[nil true false ")
    end
  end

  test "List" do
    root = node(:root, nil, [node(:list, nil)])
    assert parse("()") == root

    root = node(:root, nil, [node(:list, nil, [node(:keyword, "name"), node(:string, "John")])])
    assert parse("(:name, \"John\")") == root

    root =
      node(:root, nil, [
        node(:list, nil, [node(:keyword, "name"), node(:string, "John"), node(:integer, "120")])
      ])

    assert parse("(:name, \"John\", 120)") == root

    assert_raise Ex.UnbalancedDelimiterError, fn ->
      parse("(nil true false ")
    end
  end

  test "Set" do
    root = node(:root, nil, [node(:set, nil)])
    assert parse("#\{}") == root

    root = node(:root, nil, [node(:set, nil, [node(:keyword, "name"), node(:string, "John")])])
    assert parse("#\{:name, \"John\"}") == root

    root =
      node(:root, nil, [
        node(:set, nil, [node(:keyword, "name"), node(:string, "John"), node(:integer, "120")])
      ])

    assert parse("#\{:name, \"John\", 120}") == root

    assert_raise Ex.UnbalancedDelimiterError, fn ->
      parse("#\{ nil true false ")
    end
  end

  test "Tag" do
    root = node(:root, nil, [node(:tag, "inst", [node(:string, "1985-04-12T23:20:50.52Z")])])
    assert parse("#inst \"1985-04-12T23:20:50.52Z\"") == root

    root =
      node(:root, nil, [
        node(:tag, "some/tag", [node(:map, nil, [node(:keyword, "a"), node(:integer, "1")])])
      ])

    assert parse("#some/tag {:a 1}") == root

    assert_raise Ex.IncompleteTagError, fn ->
      parse(":some-keyword #a/tag ")
    end
  end

  test "Discard" do
    root = node(:root, nil, [node(:set, nil, [node(:keyword, "name")])])
    assert parse("#\{:name, #_ \"John\"}") == root

    root = node(:root, nil, [node(:set, nil, [node(:string, "John"), node(:integer, "120")])])
    assert parse("#\{#_:name, \"John\", 120}") == root
  end

  test "Comment" do
    root = node(:root, nil, [node(:set, nil, [node(:keyword, "name")])])
    assert parse("#\{:name, \n ;; \"John\" \n}") == root

    root = node(:root, nil, [node(:set, nil, [node(:string, "John"), node(:integer, "120")])])
    assert parse("#\{\n;; :name, \n \"John\", 120}") == root
  end

  test "Unexpected Token" do
    assert_raise Ex.UnexpectedTokenError, fn ->
      parse("#\{\n;; :name, \n \"John\", 120} }")
    end
  end

  defp node(type, value, children \\ []) do
    %Parser.Node{type: type, value: value, children: children, location: nil}
  end
end
