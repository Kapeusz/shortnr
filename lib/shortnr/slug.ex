defmodule Shortnr.Slug do
  @moduledoc """
  Stateless Snowflake-like Base62 slug generator.
  """

  import Bitwise
  alias Shortnr.Slug.Base62

  @worker_bits 10
  @seq_bits 12

  @spec generate() :: String.t()
  def generate do
    {epoch_ms, worker_id} = config()

    ts_rel = System.system_time(:millisecond) - epoch_ms
    seq = System.unique_integer([:monotonic, :positive]) &&& 0xFFF

    id = ts_rel <<< (@worker_bits + @seq_bits) ||| worker_id <<< @seq_bits ||| seq
    Base62.encode(id)
  end

  defp config do
    conf = Application.get_env(:shortnr, __MODULE__, [])
    epoch_ms = Keyword.get(conf, :epoch_ms, 1_704_067_200_000)
    worker_id =
      Keyword.get(conf, :worker_id, :auto)
      |> resolve_worker_id()
      |> validate_worker_id!()

    {epoch_ms, worker_id}
  end

  defp resolve_worker_id(:auto) do
    # Prefer Fly.io machine/allocation identifiers for per-instance worker ids.
    # Docs: https://fly.io/docs/reference/runtime-environment/
    with {:ok, mid} <- fetch_env("FLY_MACHINE_ID") do
      hash_10_bits(mid)
    else
      _ ->
        with {:ok, alloc} <- fetch_env("FLY_ALLOC_ID") do
          hash_10_bits(alloc)
        else
          _ ->
            node() |> to_string() |> hash_10_bits()
        end
    end
  end

  defp resolve_worker_id(id) when is_integer(id), do: id

  defp validate_worker_id!(id) when is_integer(id) and id >= 0 and id < (1 <<< @worker_bits), do: id
  defp validate_worker_id!(_),
    do: raise(ArgumentError, "worker_id must be an integer in 0..#{(1 <<< @worker_bits) - 1}")

  defp fetch_env(name) do
    case System.get_env(name) do
      nil -> :error
      val -> {:ok, val}
    end
  end

  defp hash_10_bits(str) when is_binary(str) do
    <<hash::unsigned-32, _::binary>> = :crypto.hash(:sha256, str)
    hash &&& 0x3FF
  end
end
