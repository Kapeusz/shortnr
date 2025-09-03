defmodule Shortnr.Urls.Url do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:shortened_url, :string, autogenerate: false}
  @derive {Phoenix.Param, key: :shortened_url}
  @timestamps_opts [type: :utc_datetime_usec]
  schema "urls" do
    field :long_url, :string
    field :redirect_count, :integer, default: 0
    field :expires_at, :utc_datetime

    timestamps()
  end

  def changeset(url, attrs) do
    url
    |> cast(attrs, [:long_url, :shortened_url, :redirect_count, :expires_at])
    |> validate_required([:long_url, :shortened_url])
    |> validate_length(:long_url, min: 1)
    |> validate_length(:shortened_url, min: 1)
    # Primary key enforces uniqueness across partitions; match any partition pk name
    |> unique_constraint(:shortened_url, name: "_pkey", match: :suffix)
  end
end
