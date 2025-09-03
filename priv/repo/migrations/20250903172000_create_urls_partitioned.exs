defmodule Shortnr.Repo.Migrations.CreateUrlsPartitioned do
  use Ecto.Migration

  def change do
    # Partitioned parent table (hash partitioning by shortened_url)
    execute(
      """
      CREATE TABLE urls (
        shortened_url text PRIMARY KEY,
        long_url text NOT NULL,
        redirect_count integer NOT NULL DEFAULT 0,
        expires_at timestamptz NULL,
        inserted_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      ) PARTITION BY HASH (shortened_url);
      """,
      "DROP TABLE IF EXISTS urls CASCADE"
    )

    #  Hash partitions to start with
    for remainder <- 0..3 do
      execute(
        """
        CREATE TABLE urls_p#{remainder}
        PARTITION OF urls
        FOR VALUES WITH (MODULUS 4, REMAINDER #{remainder});
        """,
        "DROP TABLE IF EXISTS urls_p#{remainder}"
      )
    end

    # Index to help purge or query by expiration
    create index(:urls, [:expires_at])
  end
end
