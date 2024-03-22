defmodule Eden.Decode do
  alias Eden.Parser.Node
  alias Eden.Character
  alias Eden.Symbol
  alias Eden.Tag
  alias Eden.Exception, as: Ex
  require Integer

  def decode(children, opts) when is_list(children) do
    Enum.map(children, fn x -> decode(x, opts) end)
  end

  def decode(%Node{type: :root, children: children}, opts) do
    decode(children, opts)
  end

  def decode(%Node{type: nil}, _opts) do
    nil
  end

  def decode(%Node{type: true}, _opts) do
    true
  end

  def decode(%Node{type: false}, _opts) do
    false
  end

  def decode(%Node{type: :string, value: value}, _opts) do
    value
  end

  def decode(%Node{type: :character, value: value}, _opts) do
    %Character{char: value}
  end

  def decode(%Node{type: :symbol, value: value}, _opts) do
    %Symbol{name: value}
  end

  def decode(%Node{type: :keyword, value: value}, _opts) do
    String.to_atom(value)
  end

  def decode(%Node{type: :integer, value: value}, _opts) do
    value = String.trim_trailing(value, "N")
    :erlang.binary_to_integer(value)
  end

  def decode(%Node{type: :float, value: value}, _opts) do
    value = String.trim_trailing(value, "M")
    # Elixir/Erlang don't convert to float if there
    # is no decimal part.
    final_value =
      if not String.contains?(value, ".") do
        if String.match?(value, ~r/[eE]/) do
          String.replace(value, ~r/[eE]/, ".0E")
        else
          value <> ".0"
        end
      else
        value
      end

    :erlang.binary_to_float(final_value)
  end

  def decode(%Node{type: :list, children: children}, opts) do
    decode(children, opts)
  end

  def decode(%Node{type: :vector, children: children}, opts) do
    children
    |> decode(opts)
    |> Array.from_list()
  end

  def decode(%Node{type: :map, children: children} = node, opts) do
    if Integer.is_odd(length(children)) do
      raise Ex.OddExpressionCountError, node
    end

    children
    |> decode(opts)
    |> Enum.chunk_every(2)
    |> Enum.map(fn [a, b] -> {a, b} end)
    |> Enum.into(%{})
  end

  def decode(%Node{type: :set, children: children}, opts) do
    children
    |> decode(opts)
    |> Enum.into(MapSet.new())
  end

  def decode(%Node{type: :tag, value: name, children: [child]}, opts) do
    case Map.get(opts[:handlers], name) do
      nil ->
        %Tag{name: name, value: decode(child, opts)}

      handler ->
        handler.(decode(child, opts))
    end
  end

  def decode(%Node{type: type}, _opts) do
    raise "Unrecognized node type: #{inspect(type)}"
  end
end
