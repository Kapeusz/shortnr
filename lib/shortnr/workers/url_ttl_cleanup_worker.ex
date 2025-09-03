defmodule Shortnr.Workers.UrlTtlCleanupWorker do
  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 300]

  alias Shortnr.Repo
  alias Shortnr.Urls.Url
  import Ecto.Query

  @batch_size 1000

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    deleted = delete_expired_in_batches()
    {:ok, %{deleted: deleted}}
  end

  defp delete_expired_in_batches do
    do_delete(0)
  end

  defp do_delete(acc) do
    now = DateTime.utc_now()

    ids =
      Repo.all(
        from u in Url,
          where: not is_nil(u.expires_at) and u.expires_at <= ^now,
          select: u.shortened_url,
          limit: ^@batch_size
      )

    case ids do
      [] -> acc
      ids ->
        {count, _} = Repo.delete_all(from u in Url, where: u.shortened_url in ^ids)
        if count < @batch_size, do: acc + count, else: do_delete(acc + count)
    end
  end
end

