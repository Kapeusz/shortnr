defmodule Shortnr.ReservedSlugs do
  @moduledoc """
  Reserved slugs registry backed by DB.
  """
  import Ecto.Query
  alias Shortnr.Repo

  @default_reserved ~w(admin login dashboard api dev support docs status health terms privacy help)

  @spec reserved?(String.t()) :: boolean()
  def reserved?(slug) when is_binary(slug) do
    slug_down = String.downcase(slug)

    if slug_down in @default_reserved do
      true
    else
      Repo.exists?(from r in "reserved_slugs", where: r.slug == ^slug_down, select: 1)
    end
  end
end
