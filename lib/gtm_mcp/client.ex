defmodule GtmMcp.Client do
  @moduledoc "GET de solo lectura a la Tag Manager API v2, siguiendo la paginación."

  @base "https://tagmanager.googleapis.com/tagmanager/v2/"

  @doc "Une segmentos validados en una ruta de la API. Los IDs de GTM son numéricos."
  def path(segments) do
    if Enum.all?(segments, &valid_segment?/1),
      do: {:ok, Enum.join(segments, "/")},
      else: {:error, "IDs inválidos: deben ser numéricos"}
  end

  defp valid_segment?(s), do: is_binary(s) and s =~ ~r/\A([a-z_]+|\d+|versions:live)\z/

  def get(path, page_token \\ nil, acc \\ %{}) do
    with {:ok, %{token: token}} <- token(),
         {:ok, %{status: 200, body: body}} <-
           Req.get(@base <> path, auth: {:bearer, token}, params: [pageToken: page_token], retry: :transient) do
      acc = Map.merge(acc, Map.delete(body, "nextPageToken"), fn _k, a, b -> merge(a, b) end)

      case body["nextPageToken"] do
        nil -> {:ok, acc}
        next -> get(path, next, acc)
      end
    else
      {:ok, %{status: status, body: body}} -> {:error, "GTM API #{status}: #{inspect(body["error"]["message"] || body)}"}
      {:error, reason} -> {:error, "Error de red/auth: #{Exception.message(reason)}"}
    end
  end

  defp token do
    if Process.whereis(GtmMcp.Supervisor) && Enum.any?(Supervisor.which_children(GtmMcp.Supervisor), &match?({Goth, _, _, _}, &1)),
      do: Goth.fetch(GtmMcp.Goth),
      else: {:error, %RuntimeError{message: "falta la llave de Google en #{GtmMcp.Application.credentials_path()}"}}
  end

  defp merge(a, b) when is_list(a) and is_list(b), do: a ++ b
  defp merge(_a, b), do: b
end
