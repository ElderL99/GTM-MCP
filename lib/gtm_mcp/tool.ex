defmodule GtmMcp.Tool do
  @moduledoc false
  alias Anubis.Server.Response

  @doc "Ejecuta un GET sobre los segmentos dados y lo devuelve como respuesta MCP."
  def reply(segments, frame) do
    response =
      with {:ok, path} <- GtmMcp.Client.path(segments),
           {:ok, body} <- GtmMcp.Client.get(path) do
        Response.json(Response.tool(), body)
      else
        {:error, message} -> Response.error(Response.tool(), message)
      end

    {:reply, response, frame}
  end
end
