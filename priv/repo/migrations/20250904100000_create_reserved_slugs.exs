defmodule Shortnr.Repo.Migrations.CreateReservedSlugs do
  use Ecto.Migration

  def change do
    create table(:reserved_slugs, primary_key: false) do
      add :slug, :text, primary_key: true
      add :reason, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:reserved_slugs, [:slug])
  end
end
