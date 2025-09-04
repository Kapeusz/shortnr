defmodule Shortnr.Slug.Base62 do
  @moduledoc """
  Base62 encoder for non-negative integers.

  Alphabet: 0-9, A-Z, a-z (common variant).
  """

  @alphabet ~c"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  @base 62

  @spec encode(non_neg_integer()) :: String.t()
  def encode(0), do: "0"
  def encode(int) when is_integer(int) and int > 0 do
    do_encode(int, [])
  end

  defp do_encode(0, acc), do: acc |> to_string()
  defp do_encode(int, acc) do
    rem = rem(int, @base)
    char = :lists.nth(rem + 1, @alphabet)
    do_encode(div(int, @base), [char | acc])
  end
end
