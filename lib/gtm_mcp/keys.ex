defmodule GtmMcp.Keys do
  @moduledoc """
  API keys para conectar agentes por HTTP.

  Solo se guarda el hash SHA-256 de cada key, en un archivo JSON local
  (`GTM_KEYS_FILE`, por defecto `~/.config/gtm-mcp/api_keys.json`).
  La key en claro se muestra una sola vez, al crearla.
  """
  @behaviour Anubis.Server.Authorization.Validator

  def file, do: System.get_env("GTM_KEYS_FILE") || Path.expand("~/.config/gtm-mcp/api_keys.json")

  def create(name) do
    keys = load()

    cond do
      not (is_binary(name) and name =~ ~r/\A[A-Za-z0-9_-]{1,40}\z/) ->
        {:error, "el nombre solo puede tener letras, números, - y _ (máx. 40)"}

      Enum.any?(keys, fn {_, k} -> k["name"] == name end) ->
        {:error, "ya existe una key llamada #{name}"}

      true ->
        key = "gtm_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
        save(Map.put(keys, hash(key), %{"name" => name, "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()}))
        {:ok, key}
    end
  end

  def list, do: load() |> Map.values() |> Enum.sort_by(& &1["created_at"])

  def revoke(name) do
    keys = load()
    kept = Map.reject(keys, fn {_, k} -> k["name"] == name end)

    if map_size(kept) == map_size(keys),
      do: {:error, "no existe una key llamada #{name}"},
      else: save(kept)
  end

  # Se lee el archivo en cada request: revocar una key aplica de inmediato.
  @impl true
  def validate_token(token, config) do
    case load()[hash(token)] do
      %{"name" => name} -> {:ok, %{"sub" => name, "aud" => config.resource}}
      nil -> {:error, :invalid_key}
    end
  end

  defp hash(key), do: :crypto.hash(:sha256, key) |> Base.encode16(case: :lower)

  defp load do
    case File.read(file()) do
      {:ok, json} -> JSON.decode!(json)
      {:error, :enoent} -> %{}
    end
  end

  defp save(keys) do
    File.mkdir_p!(Path.dirname(file()))
    File.write!(file(), JSON.encode!(keys))
    File.chmod!(file(), 0o600)
  end
end
