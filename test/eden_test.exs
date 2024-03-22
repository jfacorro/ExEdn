defmodule EdenTest do
  use ExUnit.Case
  import Eden
  alias Eden.Character
  alias Eden.Symbol
  alias Eden.UUID
  alias Eden.Tag
  alias Eden.Exception, as: Ex

  ## Decode

  test "Decode Empty Input" do
    e = %Ex.EmptyInputError{}
    assert decode("") == {:error, e.__struct__}

    assert_raise Ex.EmptyInputError, fn ->
      decode!("")
    end
  end

  test "Decode Literals" do
    assert decode!("nil") == nil
    assert decode!("true") == true
    assert decode!("false") == false
    assert decode!("false false") == [false, false]

    assert decode!("\"hello world!\"") == "hello world!"
    assert decode!("\"hello \\n world!\"") == "hello \n world!"

    assert decode!("\\n") == %Character{char: "n"}
    assert decode!("\\z") == %Character{char: "z"}

    assert decode!("a-symbol") == %Symbol{name: "a-symbol"}
    assert decode!(":the-keyword") == :"the-keyword"
    assert decode!(":ns/the-keyword") == :"ns/the-keyword"

    assert decode!("42") == 42
    assert decode!("42N") == 42

    assert decode!("42.0") == 42.0
    assert decode!("42M") == 42.0
    assert decode!("42.0e3") == 42000.0
    assert decode!("42e-3") == 0.042
    assert decode!("42E-1") == 4.2
    assert decode!("42.01E+1") == 420.1
  end

  test "Decode List" do
    assert decode!("(1 :a 42.0)") == [1, :a, 42.0]
  end

  test "Decode Vector" do
    array = Array.from_list([1, :a, 42.0])
    assert decode!("[1 :a 42.0]") == array
  end

  test "Decode Map" do
    map = %{name: "John", age: 42}
    assert decode!("{:name \"John\" :age 42}") == map

    assert_raise Ex.OddExpressionCountError, fn ->
      decode!("{:name \"John\" :age}")
    end
  end

  test "Decode Namespaced Map" do
    assert decode!("#:ns{:foo 1, :bar/zoo 2 :_/baz 3}") == %{"ns/foo": 1, "bar/zoo": 2, baz: 3}
  end

  test "Decode Set" do
    set = Enum.into([:name, "John", :age, 42], MapSet.new())
    assert decode!("#\{:name \"John\" :age 42}") == set
  end

  test "Decode Tag" do
    date = Timex.parse!("1985-04-12T23:20:50.52Z", "{RFC3339z}")
    assert decode!("#inst \"1985-04-12T23:20:50.52Z\"") == date

    assert decode!("#uuid \"f81d4fae-7dec-11d0-a765-00a0c91e6bf6\"") == %UUID{
             value: "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"
           }

    assert decode!("#custom/tag (1 2 3)") == %Tag{name: "custom/tag", value: [1, 2, 3]}
    handlers = %{"custom/tag" => &custom_tag_handler/1}
    assert decode!("#custom/tag (1 2 3)", handlers: handlers) == [:a, :b, :c]
  end

  ## Encode

  test "Encode Literals" do
    assert encode!(nil) == "nil"
    assert encode!(true) == "true"
    assert encode!(false) == "false"

    assert encode!("hello world!") == "\"hello world!\""
    assert encode!("hello \n world!") == "\"hello \n world!\""

    assert encode!(Character.new("n")) == "\\n"
    assert encode!(Character.new("z")) == "\\z"

    assert encode!(Symbol.new("a-symbol")) == "a-symbol"
    assert encode!(:"the-keyword") == ":the-keyword"

    assert encode!(42) == "42"

    assert encode!(42.0) == "42.0"
    assert encode!(42.0e3) == "42000.0"
    assert encode!(42.0e-3) == "0.042"
    assert encode!(42.0e-1) == "4.2"
    assert encode!(42.01e+1) == "420.1"
  end

  test "Encode List" do
    assert encode!([1, :a, 42.0]) == "(1, :a, 42.0)"
  end

  test "Encode Vector" do
    array = Array.from_list([1, :a, 42.0])
    assert encode!(array) == "[1, :a, 42.0]"
  end

  test "Encode Map" do
    map = %{name: "John", age: 42}
    assert encode!(map) == "{:name \"John\", :age 42}"
  end

  test "Encode Set" do
    assert encode!(MapSet.new([:name])) == "#\{:name}"

    set = MapSet.new([:name, "John", :age, 42])
    assert encode!(set) |> decode!() == set
  end

  test "Encode Tag" do
    date = Timex.parse!("1985-04-12T23:20:50.52Z", "{RFC3339z}")
    assert encode!(date) == "#inst \"1985-04-12T23:20:50.52Z\""
    uuid = UUID.new("f81d4fae-7dec-11d0-a765-00a0c91e6bf6")
    assert encode!(uuid) == "#uuid \"f81d4fae-7dec-11d0-a765-00a0c91e6bf6\""

    some_tag = Tag.new("custom/tag", :joni)
    assert encode!(some_tag) == "#custom/tag :joni"
  end

  test "Encode Fallback to Any" do
    node = %Eden.Parser.Node{}
    map = Map.from_struct(node)
    assert encode!(node) == encode!(map)
  end

  test "Encode Unknown Type" do
    e = %Protocol.UndefinedError{}
    assert encode(self()) == {:error, e.__struct__}

    assert_raise Protocol.UndefinedError, fn ->
      encode!(self())
    end

    try do
      encode!(self())
    rescue
      e in Protocol.UndefinedError ->
        assert e.protocol == Eden.Encode
        assert e.value == self()
    end
  end

  defp custom_tag_handler(value) when is_list(value) do
    mapping = %{1 => :a, 2 => :b, 3 => :c}
    Enum.map(value, fn x -> mapping[x] end)
  end
end
