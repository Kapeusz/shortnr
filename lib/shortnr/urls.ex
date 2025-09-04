defmodule Shortnr.Urls do
  @moduledoc """
  Context for managing shortened URLs.
  """
  import Ecto.Query, warn: false
  alias Shortnr.Repo

  alias Shortnr.Urls.Url
  alias Shortnr.Slug

  def list_urls do
    Repo.all(from u in Url, order_by: [desc: u.inserted_at, desc: u.shortened_url])
  end

  def change_url(%Url{} = url, attrs \\ %{}), do: Url.input_changeset(url, attrs)

  def create_url(attrs), do: do_create_url(attrs, 0)

  @max_retries 5
  defp do_create_url(attrs, attempt) when attempt <= @max_retries do
    case normalized_long_url(attrs) do
      {:ok, norm_long} ->
        case Repo.get_by(Url, long_url: norm_long) do
          %Url{} = url -> {:ok, url}
          nil ->
            slug = Slug.generate()
            if Shortnr.ReservedSlugs.reserved?(slug) do
              do_create_url(attrs, attempt + 1)
            else
              params =
                attrs
                |> Map.put("shortened_url", slug)
                |> Map.put("long_url", norm_long)

              %Url{}
              |> Url.changeset(params)
              |> Repo.insert()
              |> case do
                {:ok, url} ->
                  Shortnr.UrlCache.put_positive(url.shortened_url, %{long_url: url.long_url, expires_at: url.expires_at})
                  {:ok, url}
                {:error, changeset} = err ->
                  if unique_violation?(changeset) do
                    do_create_url(attrs, attempt + 1)
                  else
                    err
                  end
              end
            end
        end
      :skip ->
        # No long_url provided; proceed to normal insert path to surface validation errors
        slug = Slug.generate()
        if Shortnr.ReservedSlugs.reserved?(slug) do
          do_create_url(attrs, attempt + 1)
        else
          params = Map.put(attrs, "shortened_url", slug)

          %Url{}
          |> Url.changeset(params)
          |> Repo.insert()
          |> case do
            {:ok, url} ->
              Shortnr.UrlCache.put_positive(url.shortened_url, %{long_url: url.long_url, expires_at: url.expires_at})
              {:ok, url}
            {:error, changeset} = err ->
              if unique_violation?(changeset) do
                do_create_url(attrs, attempt + 1)
              else
                err
              end
          end
        end
    end
  end

  defp unique_violation?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:shortened_url, {_msg, opts}} -> Keyword.get(opts, :constraint) == :unique
      _ -> false
    end)
  end

  # Extract and normalize long_url when present; return :skip if not provided.
  defp normalized_long_url(attrs) when is_map(attrs) do
    raw = Map.get(attrs, "long_url") || Map.get(attrs, :long_url)
    case normalize_url(raw) do
      {:ok, normalized} -> {:ok, normalized}
      :error -> :skip
    end
  end

  defp normalize_url(url) when is_binary(url) do
    trimmed = String.trim(url)
    uri = URI.parse(trimmed)
    scheme = (uri.scheme || "") |> String.downcase()
    host = if is_binary(uri.host), do: String.downcase(uri.host), else: nil

    cond do
      scheme not in ["http", "https"] -> :error
      is_nil(host) or host == "" -> :error
      true ->
        port =
          case {scheme, uri.port} do
            {"http", 80} -> nil
            {"https", 443} -> nil
            {_, p} -> p
          end

        path = if uri.path in [nil, ""], do: "/", else: uri.path
        normalized = %URI{scheme: scheme, host: host, port: port, path: path, query: uri.query, fragment: uri.fragment}
        {:ok, URI.to_string(normalized)}
    end
  end
  defp normalize_url(_), do: :error

  @doc """
  Read URL by slug using cache with positive/negative TTLs.
  Returns {:ok, %Url{}} | :not_found
  """
  def get_by_slug_cached(slug) when is_binary(slug) do
    case Shortnr.UrlCache.get(slug) do
      {:ok, :negative} -> :not_found
      {:ok, %{long_url: long_url, expires_at: expires_at}} ->
        {:ok, %Url{shortened_url: slug, long_url: long_url, expires_at: expires_at}}
      :miss ->
        case Repo.get(Url, slug) do
          %Url{} = url ->
            Shortnr.UrlCache.put_positive(slug, %{long_url: url.long_url, expires_at: url.expires_at})
            {:ok, url}
          nil ->
            Shortnr.UrlCache.put_negative(slug)
            :not_found
        end
    end
  end

  @doc """
  Invalidate cache for a given slug.
  """
  def invalidate_cache(slug) when is_binary(slug) do
    Shortnr.UrlCache.delete(slug)
  end

  @doc """
  Update a URL and refresh cache on success.
  """
  def update_url(%Url{} = url, attrs) when is_map(attrs) do
    url
    |> Url.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        Shortnr.UrlCache.put_positive(updated.shortened_url, %{long_url: updated.long_url, expires_at: updated.expires_at})
        {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Delete a URL and invalidate cache on success.
  """
  def delete_url(%Url{} = url) do
    slug = url.shortened_url
    case Repo.delete(url) do
      {:ok, deleted} ->
        Shortnr.UrlCache.delete(slug)
        {:ok, deleted}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
