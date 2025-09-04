defmodule Shortnr.Urls.Url do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:shortened_url, :string, autogenerate: false}
  @derive {Phoenix.Param, key: :shortened_url}
  @timestamps_opts [type: :utc_datetime_usec]
  schema "urls" do
    field :long_url, :string
    field :redirect_count, :integer, default: 0
    field :expires_at, :utc_datetime_usec

    timestamps()
  end

  def changeset(url, attrs) do
    url
    |> cast(attrs, [:long_url, :shortened_url, :redirect_count, :expires_at])
    |> validate_required([:long_url, :shortened_url])
    |> validate_length(:long_url, min: 1)
    |> validate_long_url()
    |> validate_length(:shortened_url, min: 1)
    |> unique_constraint(:shortened_url, name: "_pkey", match: :suffix)
  end

  def input_changeset(url, attrs) do
    url
    |> cast(attrs, [:long_url])
    |> validate_required([:long_url])
    |> validate_length(:long_url, min: 1)
    |> validate_long_url()
  end

  defp validate_long_url(changeset) do
    validate_change(changeset, :long_url, fn :long_url, value ->
      url = if is_binary(value), do: String.trim(value), else: value

      case parse_http_url(url) do
        :ok -> []
        {:error, _reason} -> [long_url: "must be a valid http(s) URL with host"]
      end
    end)
  end

  defp parse_http_url(url) when is_binary(url) do
    uri = URI.parse(url)
    scheme = (uri.scheme || "") |> String.downcase()
    cond do
      scheme not in ["http", "https"] -> {:error, :invalid_scheme}
      is_nil(uri.host) or uri.host == "" -> {:error, :missing_host}
      true -> :ok
    end
  end
  defp parse_http_url(_), do: {:error, :invalid}
end
