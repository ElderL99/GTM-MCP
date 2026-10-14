defmodule Mix.Tasks.Gtm.Keys do
  @shortdoc "Gestiona las API keys: create NOMBRE | list | revoke NOMBRE"
  @moduledoc @shortdoc
  use Mix.Task
  alias GtmMcp.Keys

  @impl true
  def run(["create", name]) do
    case Keys.create(name) do
      {:ok, key} -> Mix.shell().info("Key para #{name} (guárdala, no se vuelve a mostrar):\n\n  #{key}\n")
      {:error, msg} -> Mix.raise(msg)
    end
  end

  def run(["list"]) do
    for k <- Keys.list(), do: Mix.shell().info("#{k["name"]}\t#{k["created_at"]}")
  end

  def run(["revoke", name]) do
    case Keys.revoke(name) do
      :ok -> Mix.shell().info("Key #{name} revocada")
      {:error, msg} -> Mix.raise(msg)
    end
  end

  def run(_), do: Mix.raise("Uso: mix gtm.keys create NOMBRE | list | revoke NOMBRE")
end
