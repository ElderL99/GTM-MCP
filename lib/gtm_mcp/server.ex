defmodule GtmMcp.Server do
  @moduledoc "Servidor MCP local y de solo lectura para Google Tag Manager."
  use Anubis.Server,
    name: "gtm",
    version: "0.1.0",
    capabilities: [:tools],
    # Solo aplica al transporte HTTP: cada agente se identifica con una API key.
    authorization: [
      authorization_servers: [],
      resource: "gtm-mcp",
      validator: {GtmMcp.Keys, []}
    ]

  component GtmMcp.Tools.ListAccounts, name: "gtm_list_accounts"
  component GtmMcp.Tools.ListContainers, name: "gtm_list_containers"
  component GtmMcp.Tools.ListWorkspaces, name: "gtm_list_workspaces"
  component GtmMcp.Tools.ListWorkspaceItems, name: "gtm_list_workspace_items"
  component GtmMcp.Tools.ListVersions, name: "gtm_list_versions"
  component GtmMcp.Tools.GetVersion, name: "gtm_get_version"
end
