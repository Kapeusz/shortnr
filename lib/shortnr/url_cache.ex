defmodule Shortnr.UrlCache do
  @moduledoc """
  ETS cache for slug lookups with positive and negative TTLs.
  """
  use GenServer

  @table :shortnr_url_cache
  @prune_interval_ms 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get(slug) when is_binary(slug) do
    key = cache_key(slug)
    case :ets.lookup(@table, key) do
      [{^key, %{value: value, exp: exp}}] ->
        now = System.system_time(:millisecond)
        if now < exp do
          {:ok, value}
        else
          :ets.delete(@table, key)
          :miss
        end
      _ -> :miss
    end
  end

  def put_positive(slug, value, ttl_ms \\ nil) when is_binary(slug) do
    ttl = ttl_ms || pos_ttl()
    exp = System.system_time(:millisecond) + ttl
    true = :ets.insert(@table, {cache_key(slug), %{value: value, exp: exp}})
    :ok
  end

  def put_negative(slug, ttl_ms \\ nil) when is_binary(slug) do
    ttl = ttl_ms || neg_ttl()
    exp = System.system_time(:millisecond) + ttl
    true = :ets.insert(@table, {cache_key(slug), %{value: :negative, exp: exp}})
    :ok
  end

  def delete(slug) when is_binary(slug) do
    :ets.delete(@table, cache_key(slug))
    :ok
  end

  @impl true
  def init(_opts) do
    tid = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])
    Process.send_after(self(), :prune, @prune_interval_ms)
    {:ok, %{table: tid}}
  end

  @impl true
  def handle_info(:prune, state) do
    now = System.system_time(:millisecond)
    match = {
      :_,
      %{value: :_, exp: :'$1'}
    }
    guard = [{:<, :'$1', now}]
    result = [true]
    :ets.select_delete(@table, [{match, guard, result}])
    Process.send_after(self(), :prune, @prune_interval_ms)
    {:noreply, state}
  end

  defp cache_key(slug), do: "url:" <> slug

  defp pos_ttl do
    Application.get_env(:shortnr, __MODULE__, [])
    |> Keyword.get(:positive_ttl_ms, 60_000)
  end

  defp neg_ttl do
    Application.get_env(:shortnr, __MODULE__, [])
    |> Keyword.get(:negative_ttl_ms, 5_000)
  end
end
