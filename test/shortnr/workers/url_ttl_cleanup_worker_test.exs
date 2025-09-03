defmodule Shortnr.Workers.UrlTtlCleanupWorkerTest do
  use Shortnr.DataCase, async: true

  import Ecto.Query
  import Shortnr.UrlsFixtures

  alias Shortnr.Repo
  alias Shortnr.Urls.Url
  alias Shortnr.Workers.UrlTtlCleanupWorker

  defp past_datetime(seconds \\ 60), do: DateTime.add(DateTime.utc_now(), -seconds, :second)
  defp future_datetime(seconds \\ 60), do: DateTime.add(DateTime.utc_now(), seconds, :second)

  describe "perform/1" do
    test "deletes only expired urls and keeps future/null" do
      # expired rows
      u_expired = url_fixture(%{expires_at: past_datetime(), long_url: "https://example.com/expired"})
      u_now = url_fixture(%{expires_at: DateTime.utc_now(), long_url: "https://example.com/now"})

      # non-expired rows
      u_future = url_fixture(%{expires_at: future_datetime(), long_url: "https://example.com/future"})
      u_null = url_fixture(%{long_url: "https://example.com/null"})

      assert {:ok, %{deleted: 2}} = UrlTtlCleanupWorker.perform(%Oban.Job{})

      # Expired are gone
      refute Repo.get(Url, u_expired.shortened_url)
      refute Repo.get(Url, u_now.shortened_url)

      # Future and NULL remain
      assert Repo.get(Url, u_future.shortened_url)
      assert Repo.get(Url, u_null.shortened_url)
    end

    test "deletes in batches larger than batch size" do
      # The worker uses a batch size of 1000; create > 1000 expired rows
      expires_at = past_datetime()
      count = 1001

      entries =
        for i <- 1..count do
          %{long_url: "https://batch.example/#{i}", shortened_url: unique_slug(), expires_at: expires_at}
        end

      # Bulk insert for speed
      {^count, _} = Repo.insert_all(Url, entries)

      assert {:ok, %{deleted: ^count}} = UrlTtlCleanupWorker.perform(%Oban.Job{})

      # Ensure no rows with our batch marker remain
      remaining = Repo.aggregate(from(u in Url, where: like(u.long_url, ^"https://batch.example/%")), :count)
      assert remaining == 0
    end

    test "is idempotent when nothing is expired" do
      # Ensure there are no expired rows
      url_fixture(%{expires_at: future_datetime(), long_url: "https://example.com/keep1"})
      url_fixture(%{long_url: "https://example.com/keep2"})

      assert {:ok, %{deleted: 0}} = UrlTtlCleanupWorker.perform(%Oban.Job{})
    end
  end
end

