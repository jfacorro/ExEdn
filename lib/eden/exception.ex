defmodule Eden.Exception do
  defmodule Util do
    def token_message(token) do
      msg = "(#{inspect(token.type)}) #{inspect(token.value)}"

      if Map.has_key?(token, :location) do
        loc = token.location
        msg <> " at line #{inspect(loc.line)} and column #{inspect(loc.col)}."
      else
        msg
      end
    end
  end

  ## Lexer Exceptions

  defmodule UnexpectedInputError do
    defexception [:message]

    def exception(msg) do
      %UnexpectedInputError{message: msg}
    end
  end

  defmodule UnfinishedTokenError do
    defexception [:message]

    def exception(token) do
      %UnfinishedTokenError{message: Util.token_message(token)}
    end
  end

  ## Parser Exceptions

  defmodule UnexpectedTokenError do
    defexception [:message]

    def exception(token) do
      %UnexpectedTokenError{message: Util.token_message(token)}
    end
  end

  defmodule UnbalancedDelimiterError do
    defexception [:message]

    def exception(msg) do
      %UnbalancedDelimiterError{message: "#{inspect(msg)}"}
    end
  end

  defmodule OddExpressionCountError do
    defexception [:message]

    def exception(msg) do
      %OddExpressionCountError{message: "#{inspect(msg)}"}
    end
  end

  defmodule IncompleteTagError do
    defexception [:message]

    def exception(msg) do
      %IncompleteTagError{message: "#{inspect(msg)}"}
    end
  end

  defmodule MissingDiscardExpressionError do
    defexception [:message]

    def exception(msg) do
      %MissingDiscardExpressionError{message: "#{inspect(msg)}"}
    end
  end

  ## Decode Exceptions

  defmodule EmptyInputError do
    defexception [:message]

    def exception(msg) do
      %EmptyInputError{message: "#{inspect(msg)}"}
    end
  end

  defmodule NotImplementedError do
    defexception [:message]

    def exception(msg) when is_binary(msg) do
      %NotImplementedError{message: msg}
    end

    def exception({function, arity}) do
      function = Atom.to_string(function)
      %NotImplementedError{message: "#{function}/#{inspect(arity)}"}
    end
  end
end
