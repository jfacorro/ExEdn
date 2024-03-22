defmodule Eden.Parser.Node do
  defstruct type: nil, location: nil, value: nil, children: []
  @behaviour Access

  def fetch(map, key) do
    Map.fetch(map, key)
  end

  def get(map, key, value) do
    Map.get(map, key, value)
  end

  def pop(map, key) do
    Map.pop(map, key)
  end

  def get_and_update(%{} = map, key, fun) do
    Map.get_and_update(map, key, fun)
  end

  defimpl Inspect, for: __MODULE__ do
    import Inspect.Algebra

    def inspect(node, opts) do
      type_str = ":" <> Atom.to_string(node.type)
      value_str = if node.value, do: "\"" <> node.value <> "\" ", else: ""

      loc = node.location

      location_str =
        if loc do
          concat(["(", Integer.to_string(loc.line), ",", Integer.to_string(loc.col), ")"])
        else
          ""
        end

      level = Map.get(opts, :level, 0)
      opts = Map.put(opts, :level, level + 2)
      padding = String.duplicate(" ", level)

      concat(
        [padding, "", type_str, " ", value_str, location_str, "\n"] ++
          Enum.map(node.children, fn x -> to_doc(x, opts) end)
      )
    end
  end

  def reverse_children(node) do
    update_in(node, [:children], &Enum.reverse/1)
  end
end
