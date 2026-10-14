defmodule GtmMcp.Application do
  @moduledoc false
  use Application

  @scopes ["https://www.googleapis.com/auth/tagmanager.readonly"]

  @impl true
  def start(_type, _args) do
    # Claude cierra stdin al desconectarse: apagamos la VM en vez de quedar huérfanos.
    :telemetry.attach(
      "gtm-mcp-halt-on-eof",
      [:anubis_mcp, :transport, :disconnect],
      fn _event, _measurements, meta, _ -> if meta[:reason] == :eof, do: System.stop(0) end,
      nil
    )

    children = goth_children() ++ transport_children(System.get_env("GTM_TRANSPORT", "stdio"))

    Supervisor.start_link(children, strategy: :one_for_one, name: GtmMcp.Supervisor)
  end

  defp transport_children("stdio"), do: [{GtmMcp.Server, transport: :stdio}]

  # ponytail: HTTP plano en 127.0.0.1. Para exponerlo en red, poner TLS delante (Caddy/nginx).
  defp transport_children("http") do
    {:ok, ip} = :inet.parse_address(String.to_charlist(System.get_env("GTM_HTTP_IP", "127.0.0.1")))

    [
      {GtmMcp.Server, transport: :streamable_http},
      {Bandit,
       plug: {Anubis.Server.Transport.StreamableHTTP.Plug, server: GtmMcp.Server},
       ip: ip,
       # HTTP/2 apagado: EEF-CVE-2026-105659 sin parche en bandit 1.12.5. MCP solo necesita HTTP/1.1.
       http_2_options: [enabled: false],
       port: String.to_integer(System.get_env("GTM_HTTP_PORT", "4100"))},
      # Admin de keys: siempre solo en esta máquina, aunque el MCP se exponga en red.
      {Bandit,
       plug: GtmMcp.Admin,
       ip: {127, 0, 0, 1},
       http_2_options: [enabled: false],
       port: String.to_integer(System.get_env("GTM_ADMIN_PORT", "4101"))}
    ]
  end

  def credentials_path,
    do: System.get_env("GTM_CREDENTIALS") || Path.expand("~/.config/gtm-mcp/service-account.json")

  # Sin llave de Google el servidor arranca igual (la UI de keys sigue sirviendo);
  # las herramientas de GTM responden con un error claro.
  defp goth_children do
    case File.read(credentials_path()) do
      {:ok, json} ->
        [{Goth, name: GtmMcp.Goth, source: {:service_account, JSON.decode!(json), scopes: @scopes}}]

      {:error, reason} ->
        require Logger
        Logger.warning("Sin llave de Google en #{credentials_path()}: #{:file.format_error(reason)}")
        []
    end
  end
end
