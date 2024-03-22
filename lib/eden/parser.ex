defmodule Eden.Parser do
  alias Eden.Lexer
  alias Eden.Parser.Node
  alias Eden.Exception, as: Ex

  @moduledoc """
  Provides a single function that returns an `Eden.Parser.Node`
  struct, which is the `:root` node of the parse tree.
  """

  require Logger

  @doc """
  Takes a string and returns the root node of the parse tree.

  All nodes are an `Eden.Parser.Node` struct, each of which has a `:type`,
  a `:value` and an optional `:location` property.

  The returned node is always of type `:root`, whose children are all the
  expressions found in the string provided.

  Options:

  - `:location` - a `boolean` that determines if nodes should include row and column information.

  ## Examples

      iex> Eden.Parser.parse("nil")
      :root
        :nil "nil"

      iex> Eden.Parse.parse("nil", location: true)
      :root
        :nil "nil" (1,0)

      iex> Eden.Parse.parse("[1 2 3]")
      :root
        :vector
          :integer "1"
          :integer "2"
          :integer "3"

      iex> Eden.Parse.parse("[1 2 3]", location: true)
      :root
        :vector (1,0)
          :integer "1" (1,1)
          :integer "2" (1,3)
          :integer "3" (1,5)
  """
  def parse(input, opts \\ [location: false]) when is_binary(input) do
    tokens = Lexer.tokenize(input, opts)
    state = %{tokens: tokens, node: new_node(:root)}
    state = exprs(state)

    if not Enum.empty?(state.tokens) do
      raise Ex.UnexpectedTokenError, List.first(state.tokens)
    end

    Node.reverse_children(state.node)
  end

  ##############################################################################
  ## Rules and Productions
  ##############################################################################

  defp exprs(state) do
    state
    |> expr
    |> skip_when(&exprs/1, &is_nil/1)
    |> return_when(state, &is_nil/1)
  end

  defp expr(%{tokens: []}) do
    nil
  end

  defp expr(state) do
    terminal(state, nil) ||
      terminal(state, false) ||
      terminal(state, true) ||
      terminal(state, :symbol) ||
      terminal(state, :keyword) ||
      terminal(state, :integer) ||
      terminal(state, :float) ||
      terminal(state, :string) ||
      terminal(state, :character) ||
      map_begin(state) ||
      vector_begin(state) ||
      list_begin(state) ||
      set_begin(state) ||
      tag(state) ||
      discard(state) ||
      comment(state)
  end

  defp terminal(state, type) do
    {state, token} = pop_token(state)

    if token?(token, type) do
      node = new_node(type, token, true)
      add_node(state, node)
    end
  end

  ## Map

  defp map_begin(state) do
    {state, token} = pop_token(state)

    if token?(token, :curly_open) do
      state
      |> set_node(new_node(:map, token))
      |> pairs
      |> map_end
      |> restore_node(state)
    end
  end

  defp pairs(state) do
    state
    |> pair
    |> skip_when(&pairs/1, &is_nil/1)
    |> return_when(state, &is_nil/1)
  end

  defp pair(state) do
    state
    |> expr
    |> skip_when(&pair2/1, &is_nil/1)
  end

  defp pair2(state) do
    state
    |> expr
    |> raise_when(Ex.OddExpressionCountError, state, &is_nil/1)
  end

  defp map_end(state) do
    {state, token} = pop_token(state)

    if not token?(token, :curly_close) do
      raise Ex.UnbalancedDelimiterError, state.node
    end

    state
  end

  ## Vector

  defp vector_begin(state) do
    {state, token} = pop_token(state)

    if token?(token, :bracket_open) do
      state
      |> set_node(new_node(:vector, token))
      |> exprs
      |> vector_end
      |> restore_node(state)
    end
  end

  defp vector_end(state) do
    {state, token} = pop_token(state)

    if not token?(token, :bracket_close) do
      raise Ex.UnbalancedDelimiterError, state.node
    end

    state
  end

  ## List

  defp list_begin(state) do
    {state, token} = pop_token(state)

    if token?(token, :paren_open) do
      state
      |> set_node(new_node(:list, token))
      |> exprs
      |> list_end
      |> restore_node(state)
    end
  end

  defp list_end(state) do
    {state, token} = pop_token(state)

    if not token?(token, :paren_close) do
      raise Ex.UnbalancedDelimiterError, state.node
    end

    state
  end

  ## Set

  defp set_begin(state) do
    {state, token} = pop_token(state)

    if token?(token, :set_open) do
      state
      |> set_node(new_node(:set, token))
      |> exprs
      |> set_end
      |> restore_node(state)
    end
  end

  defp set_end(state) do
    {state, token} = pop_token(state)

    if not token?(token, :curly_close) do
      raise Ex.UnbalancedDelimiterError, state.node
    end

    state
  end

  ## Tag

  defp tag(state) do
    {state, token} = pop_token(state)

    if token?(token, :tag) do
      node = new_node(:tag, token, true)

      state
      |> set_node(node)
      |> expr
      |> raise_when(Ex.IncompleteTagError, node, &is_nil/1)
      |> restore_node(state)
    end
  end

  ## Discard

  defp discard(state) do
    {state, token} = pop_token(state)

    if token?(token, :discard) do
      state
      |> set_node(new_node(:discard, token))
      |> expr
      |> raise_when(Ex.MissingDiscardExpressionError, state, &is_nil/1)
      |> restore_node(state, false)
    end
  end

  ## Comment

  defp comment(state) do
    {state, token} = pop_token(state)

    if token?(token, :comment) do
      state
    end
  end

  ##############################################################################
  ## Helper functions
  ##############################################################################

  ## Node

  defp new_node(type, token \\ nil, use_value? \\ false) do
    location =
      if token && Map.has_key?(token, :location) do
        token.location
      end

    value =
      if token && use_value? do
        token.value
      end

    %Node{type: type, location: location, value: value, children: []}
  end

  defp add_node(state, node) do
    update_in(state, [:node, :children], fn children ->
      [node | children]
    end)
  end

  defp set_node(state, node) do
    Map.put(state, :node, node)
  end

  defp restore_node(new_state, old_state, add_child? \\ true) do
    child_node = Node.reverse_children(new_state.node)
    old_state = Map.put(new_state, :node, old_state.node)

    if add_child? do
      add_node(old_state, child_node)
    else
      old_state
    end
  end

  ## Token

  defp token?(nil, _), do: false
  defp token?(token, type), do: token.type == type

  defp pop_token(state) do
    {update_in(state, [:tokens], &tail/1), List.first(state.tokens)}
  end

  ## Utils

  defp return_when(x, y, pred?) do
    if(pred?.(x), do: y, else: x)
  end

  defp skip_when(x, fun, pred?) do
    if(pred?.(x), do: x, else: fun.(x))
  end

  defp raise_when(x, ex, msg, pred?) do
    if(pred?.(x), do: raise(ex, msg), else: x)
  end

  defp tail([]), do: []
  defp tail(list), do: tl(list)
end
