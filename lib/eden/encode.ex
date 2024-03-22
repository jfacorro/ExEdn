alias Eden.Encode
alias Eden.Encode.Utils
alias Eden.Character
alias Eden.Symbol
alias Eden.UUID
alias Eden.Tag

defprotocol Eden.Encode do
  @fallback_to_any true

  @spec encode(any) :: String.t()
  def encode(value)
end

defmodule Eden.Encode.Utils do
  def wrap(str, first, last) do
    first <> str <> last
  end
end

defimpl Encode, for: Atom do
  def encode(atom) when atom in [nil, true, false] do
    Atom.to_string(atom)
  end

  def encode(atom) do
    ":" <> Atom.to_string(atom)
  end
end

defimpl Encode, for: Symbol do
  def encode(symbol) do
    symbol.name
  end
end

defimpl Encode, for: BitString do
  def encode(string) do
    "\"#{string}\""
  end
end

defimpl Encode, for: Character do
  def encode(char) do
    "\\#{char.char}"
  end
end

defimpl Encode, for: Integer do
  def encode(int) do
    "#{inspect(int)}"
  end
end

defimpl Encode, for: Float do
  def encode(float) do
    "#{inspect(float)}"
  end
end

defimpl Encode, for: List do
  def encode(list) do
    list
    |> Enum.map(&Encode.encode/1)
    |> Enum.join(", ")
    |> Utils.wrap("(", ")")
  end
end

defimpl Encode, for: Array do
  def encode(array) do
    array
    |> Array.to_list()
    |> Enum.map(&Encode.encode/1)
    |> Enum.join(", ")
    |> Utils.wrap("[", "]")
  end
end

defimpl Encode, for: Map do
  def encode(map) do
    map
    |> Map.to_list()
    |> Enum.map(fn {k, v} -> Encode.encode(k) <> " " <> Encode.encode(v) end)
    |> Enum.join(", ")
    |> Utils.wrap("{", "}")
  end
end

defimpl Encode, for: MapSet do
  def encode(set) do
    set
    |> Enum.map(&Encode.encode/1)
    |> Enum.join(", ")
    |> Utils.wrap("#\{", "}")
  end
end

defimpl Encode, for: Tag do
  def encode(tag) do
    value = Encode.encode(tag.value)
    "##{tag.name} #{value}"
  end
end

defimpl Encode, for: UUID do
  def encode(uuid) do
    Encode.encode(Tag.new("uuid", uuid.value))
  end
end

defimpl Encode, for: DateTime do
  def encode(datetime) do
    value = Timex.format!(datetime, "{RFC3339z}")
    Encode.encode(Tag.new("inst", value))
  end
end

defimpl Encode, for: Any do
  def encode(struct) when is_map(struct) do
    Encode.encode(Map.from_struct(struct))
  end

  def encode(value) do
    raise %Protocol.UndefinedError{protocol: Encode, value: value}
  end
end
