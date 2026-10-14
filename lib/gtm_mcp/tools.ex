defmodule GtmMcp.Tools.ListAccounts do
  @moduledoc "Lista las cuentas de GTM a las que tiene acceso la cuenta de servicio."
  use Anubis.Server.Component, type: :tool

  schema do
  end

  @impl true
  def execute(_params, frame), do: GtmMcp.Tool.reply(["accounts"], frame)
end

defmodule GtmMcp.Tools.ListContainers do
  @moduledoc "Lista los contenedores de una cuenta de GTM."
  use Anubis.Server.Component, type: :tool

  schema do
    field :account_id, :string, required: true, description: "ID numérico de la cuenta"
  end

  @impl true
  def execute(%{account_id: a}, frame), do: GtmMcp.Tool.reply(["accounts", a, "containers"], frame)
end

defmodule GtmMcp.Tools.ListWorkspaces do
  @moduledoc "Lista los workspaces de un contenedor."
  use Anubis.Server.Component, type: :tool

  schema do
    field :account_id, :string, required: true, description: "ID numérico de la cuenta"
    field :container_id, :string, required: true, description: "ID numérico del contenedor"
  end

  @impl true
  def execute(%{account_id: a, container_id: c}, frame),
    do: GtmMcp.Tool.reply(["accounts", a, "containers", c, "workspaces"], frame)
end

defmodule GtmMcp.Tools.ListWorkspaceItems do
  @moduledoc "Lista tags, triggers, variables u otros elementos de un workspace."
  use Anubis.Server.Component, type: :tool

  @kinds ~w(tags triggers variables built_in_variables folders templates clients zones transformations)

  schema do
    field :account_id, :string, required: true, description: "ID numérico de la cuenta"
    field :container_id, :string, required: true, description: "ID numérico del contenedor"
    field :workspace_id, :string, required: true, description: "ID numérico del workspace"
    field :kind, :enum, values: @kinds, required: true, description: "Tipo de elemento a listar"
  end

  @impl true
  def execute(%{account_id: a, container_id: c, workspace_id: w, kind: kind}, frame),
    do: GtmMcp.Tool.reply(["accounts", a, "containers", c, "workspaces", w, kind], frame)
end

defmodule GtmMcp.Tools.ListVersions do
  @moduledoc "Lista las versiones publicadas de un contenedor (solo encabezados)."
  use Anubis.Server.Component, type: :tool

  schema do
    field :account_id, :string, required: true, description: "ID numérico de la cuenta"
    field :container_id, :string, required: true, description: "ID numérico del contenedor"
  end

  @impl true
  def execute(%{account_id: a, container_id: c}, frame),
    do: GtmMcp.Tool.reply(["accounts", a, "containers", c, "version_headers"], frame)
end

defmodule GtmMcp.Tools.GetVersion do
  @moduledoc "Obtiene una versión completa de un contenedor (tags, triggers, variables). Usa \"live\" para la versión publicada."
  use Anubis.Server.Component, type: :tool

  schema do
    field :account_id, :string, required: true, description: "ID numérico de la cuenta"
    field :container_id, :string, required: true, description: "ID numérico del contenedor"
    field :version_id, :string, required: true, description: "ID numérico de la versión, o \"live\""
  end

  @impl true
  def execute(%{account_id: a, container_id: c, version_id: "live"}, frame),
    do: GtmMcp.Tool.reply(["accounts", a, "containers", c, "versions:live"], frame)

  def execute(%{account_id: a, container_id: c, version_id: v}, frame),
    do: GtmMcp.Tool.reply(["accounts", a, "containers", c, "versions", v], frame)
end
