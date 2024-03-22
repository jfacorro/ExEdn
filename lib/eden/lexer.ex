defmodule Eden.Lexer do
  alias Eden.Exception, as: Ex

  @moduledoc """
  A module that implements a lexer for the edn format through its
  only function `tokenize/1`.
  """

  defmodule Token do
    defstruct type: nil, value: nil
  end

  ##############################################################################
  ## API
  ##############################################################################

  @doc """
  Takes a string and returns a list of tokens.

  Options:

  - `:location` - a `boolean` that determines wether the location information
     should be included with each token. Lines are one-based and columns are
     zero-based. The default value for `:location` is `false`.

  ## Examples

      iex> Eden.Lexer.tokenize("nil")
      [%Eden.Lexer.Token{type: nil, value: "nil"}]

      iex> Eden.Lexer.tokenize("nil", location: true)
      [%Eden.Lexer.Token{location: %{col: 0, line: 1}, type: nil, value: "nil"}]
  """
  def tokenize(input, opts \\ [location: false]) do
    initial_state = %{
      state: :new,
      tokens: [],
      current: nil,
      opts: opts,
      location: %{line: 1, col: 0}
    }

    _tokenize(initial_state, input)
  end

  ##############################################################################
  ## Private functions
  ##############################################################################

  # End of input
  defp _tokenize(state, <<>>) do
    state
    |> valid?
    |> add_token(state.current)
    |> Map.get(:tokens)
    |> Enum.reverse()
  end

  # Comment
  defp _tokenize(state = %{state: :new}, <<";"::utf8, rest::binary>>) do
    token = token(:comment, "")
    start_token(state, :comment, token, ";", rest)
  end

  defp _tokenize(state = %{state: :comment}, <<char::utf8, rest::binary>>)
       when <<char::utf8>> in ["\n", "\r"] do
    end_token(state, <<char::utf8>>, rest)
  end

  defp _tokenize(state = %{state: :comment}, <<";"::utf8, rest::binary>>) do
    skip_char(state, ";", rest)
  end

  defp _tokenize(state = %{state: :comment}, <<char::utf8, rest::binary>>) do
    consume_char(state, <<char::utf8>>, rest)
  end

  # Literals
  defp _tokenize(state = %{state: :new}, <<"nil"::utf8, rest::binary>>) do
    token = token(nil, "nil")
    start_token(state, :check_literal, token, "nil", rest)
  end

  defp _tokenize(state = %{state: :new}, <<"true"::utf8, rest::binary>>) do
    token = token(true, "true")
    start_token(state, :check_literal, token, "true", rest)
  end

  defp _tokenize(state = %{state: :new}, <<"false"::utf8, rest::binary>>) do
    token = token(false, "false")
    start_token(state, :check_literal, token, "false", rest)
  end

  defp _tokenize(state = %{state: :check_literal}, <<char::utf8, _::binary>> = input) do
    if separator?(<<char::utf8>>) do
      end_token(state, "", input)
    else
      token = token(:symbol, state.current.value)
      start_token(state, :symbol, token, "", input)
    end
  end

  # String
  defp _tokenize(state = %{state: :new}, <<"\""::utf8, rest::binary>>) do
    token = token(:string, "")
    start_token(state, :string, token, "\"", rest)
  end

  defp _tokenize(state = %{state: :string}, <<"\\"::utf8, char::utf8, rest::binary>>) do
    # TODO: this will cause the line count to get corrupted,
    #       either use the original or send the real content as
    #       an optional argument.
    consume_char(state, escaped_char(<<char::utf8>>), rest, <<"\\"::utf8, char::utf8>>)
  end

  defp _tokenize(state = %{state: :string}, <<"\""::utf8, rest::binary>>) do
    end_token(state, "\"", rest)
  end

  defp _tokenize(state = %{state: :string}, <<char::utf8, rest::binary>>) do
    consume_char(state, <<char::utf8>>, rest)
  end

  # Character
  defp _tokenize(state = %{state: :new}, <<"\\"::utf8, char::utf8, rest::binary>>) do
    token = token(:character, <<char::utf8>>)
    end_token(state, token, "\\" <> <<char::utf8>>, rest)
  end

  # Keyword and Symbol
  defp _tokenize(state = %{state: :new}, <<":"::utf8, rest::binary>>) do
    token = token(:keyword, "")
    start_token(state, :symbol, token, ":", rest)
  end

  defp _tokenize(state = %{state: :symbol}, <<"/"::utf8, rest::binary>>) do
    if not String.contains?(state.current.value, "/") do
      consume_char(state, <<"/"::utf8>>, rest)
    else
      raise Ex.UnexpectedInputError, "/"
    end
  end

  defp _tokenize(state = %{state: :symbol}, <<c::utf8, rest::binary>> = input) do
    if symbol_char?(<<c::utf8>>) do
      consume_char(state, <<c::utf8>>, rest)
    else
      end_token(state, "", input)
    end
  end

  # Integers & Float
  defp _tokenize(state = %{state: :new}, <<sign::utf8, rest::binary>>)
       when <<sign>> in ["-", "+"] do
    token = token(:integer, <<sign>>)
    start_token(state, :number, token, <<sign>>, rest)
  end

  defp _tokenize(state = %{state: :exponent}, <<sign::utf8, rest::binary>>)
       when <<sign>> in ["-", "+"] do
    consume_char(state, <<sign::utf8>>, rest)
  end

  defp _tokenize(state = %{state: :number}, <<"N"::utf8, rest::binary>>) do
    state = append_to_current(state, "N")
    end_token(state, "N", rest)
  end

  defp _tokenize(state = %{state: :number}, <<"M"::utf8, rest::binary>>) do
    state = append_to_current(state, "M")
    token = token(:float, state.current.value)
    end_token(state, token, "M", rest)
  end

  defp _tokenize(state = %{state: :number}, <<"."::utf8, rest::binary>>) do
    state = append_to_current(state, ".")
    token = token(:float, state.current.value)
    start_token(state, :fraction, token, ".", rest)
  end

  defp _tokenize(state = %{state: :number}, <<char::utf8, rest::binary>>)
       when <<char::utf8>> in ["e", "E"] do
    state = append_to_current(state, <<char::utf8>>)
    token = token(:float, state.current.value)
    start_token(state, :exponent, token, <<char::utf8>>, rest)
  end

  defp _tokenize(state = %{state: s}, <<char::utf8, rest::binary>> = input)
       when s in [:number, :exponent, :fraction] do
    cond do
      digit?(<<char::utf8>>) ->
        state
        |> set_state(:number)
        |> consume_char(<<char::utf8>>, rest)

      s in [:exponent, :fraction] and separator?(<<char::utf8>>) ->
        raise Ex.UnfinishedTokenError, state.current

      separator?(<<char::utf8>>) ->
        end_token(state, "", input)

      true ->
        raise Ex.UnexpectedInputError, <<char::utf8>>
    end
  end

  # Delimiters
  defp _tokenize(state = %{state: :new}, <<delim::utf8, rest::binary>>)
       when <<delim>> in ["{", "}", "[", "]", "(", ")"] do
    delim = <<delim>>
    token = token(delim_type(delim), delim)
    end_token(state, token, delim, rest)
  end

  defp _tokenize(state = %{state: :new}, <<"#\{"::utf8, rest::binary>>) do
    token = token(:set_open, "#\{")
    end_token(state, token, "#\{", rest)
  end

  # Whitespace
  defp _tokenize(state = %{state: :new}, <<whitespace::utf8, rest::binary>>)
       when <<whitespace>> in [" ", "\t", "\r", "\n", ","] do
    skip_char(state, <<whitespace>>, rest)
  end

  # Discard
  defp _tokenize(state = %{state: :new}, <<"#_"::utf8, rest::binary>>) do
    token = token(:discard, "#_")
    end_token(state, token, "#_", rest)
  end

  # Tags
  defp _tokenize(state = %{state: :new}, <<"#"::utf8, rest::binary>>) do
    token = token(:tag, "")
    start_token(state, :symbol, token, "#", rest)
  end

  # Symbol, Integer or Invalid input
  defp _tokenize(state = %{state: :new}, <<char::utf8, rest::binary>>) do
    cond do
      alpha?(<<char::utf8>>) ->
        token = token(:symbol, <<char::utf8>>)
        start_token(state, :symbol, token, <<char::utf8>>, rest)

      digit?(<<char::utf8>>) ->
        token = token(:integer, <<char::utf8>>)
        start_token(state, :number, token, <<char::utf8>>, rest)

      true ->
        raise Ex.UnexpectedInputError, <<char::utf8>>
    end
  end

  # Unexpected Input
  defp _tokenize(_, <<char::utf8, _::binary>>) do
    raise Ex.UnexpectedInputError, <<char::utf8>>
  end

  ##############################################################################
  ## Helper functions
  ##############################################################################

  defp start_token(state, name, token, char, rest) do
    state
    |> set_state(name)
    |> set_token(token)
    |> update_location(char)
    |> _tokenize(rest)
  end

  defp consume_char(state, char, rest, real_char \\ nil) when is_binary(char) do
    state
    |> update_location(real_char || char)
    |> append_to_current(char)
    |> _tokenize(rest)
  end

  defp skip_char(state, char, rest) when is_binary(char) do
    state
    |> update_location(char)
    |> _tokenize(rest)
  end

  defp end_token(state, char, rest) do
    state
    |> update_location(char)
    |> add_token(state.current)
    |> reset
    |> _tokenize(rest)
  end

  defp end_token(state, token, char, rest) do
    state
    |> set_token(token)
    |> end_token(char, rest)
  end

  defp update_location(state, "") do
    state
  end

  defp update_location(state, <<"\n"::utf8, rest::binary>>) do
    state
    |> put_in([:location, :line], state.location.line + 1)
    |> put_in([:location, :col], 0)
    |> update_location(rest)
  end

  defp update_location(state, <<"\r"::utf8, rest::binary>>) do
    update_location(state, rest)
  end

  defp update_location(state, <<_::utf8, rest::binary>>) do
    state
    |> put_in([:location, :col], state.location.col + 1)
    |> update_location(rest)
  end

  defp token(type, value) do
    %Token{type: type, value: value}
  end

  defp set_token(state, token) do
    token =
      if state.opts[:location] do
        Map.put(token, :location, state.location)
      else
        token
      end

    Map.put(state, :current, token)
  end

  defp set_state(state, name) do
    Map.put(state, :state, name)
  end

  defp append_to_current(%{current: current} = state, c) do
    current = %{current | value: current.value <> c}
    %{state | current: current}
  end

  defp reset(state) do
    %{state | state: :new, current: nil}
  end

  defp valid?(%{state: state, current: current})
       when state in [:string, :exponent, :character, :fraction] do
    raise Ex.UnfinishedTokenError, current
  end

  defp valid?(state) do
    state
  end

  defp add_token(state, nil) do
    state
  end

  defp add_token(state, token) do
    if token.type == :keyword and token.value == "" do
      raise Ex.UnfinishedTokenError, token
    end

    %{state | tokens: [token | state.tokens]}
  end

  defp delim_type("{"), do: :curly_open
  defp delim_type("}"), do: :curly_close
  defp delim_type("["), do: :bracket_open
  defp delim_type("]"), do: :bracket_close
  defp delim_type("("), do: :paren_open
  defp delim_type(")"), do: :paren_close

  defp escaped_char("\""), do: "\""
  defp escaped_char("t"), do: "\t"
  defp escaped_char("r"), do: "\r"
  defp escaped_char("n"), do: "\n"
  defp escaped_char("\\"), do: "\\"

  defp alpha?(char), do: String.match?(char, ~r/[a-zA-Z]/)

  defp digit?(char), do: String.match?(char, ~r/[0-9]/)

  defp symbol_char?(char), do: String.match?(char, ~r/[_?a-zA-Z0-9.*+!\-$%&=<>\#:]/)

  defp whitespace?(char), do: String.match?(char, ~r/[\s,]/)

  defp delim?(char), do: String.match?(char, ~r/[\{\}\[\]\(\)]/)

  defp separator?(char), do: whitespace?(char) or delim?(char)
end
