defmodule GtmMcp.ClientTest do
  use ExUnit.Case, async: true
  alias GtmMcp.Client

  test "acepta IDs numéricos y nombres de recurso" do
    assert {:ok, "accounts/1/containers/2/versions:live"} =
             Client.path(["accounts", "1", "containers", "2", "versions:live"])
  end

  test "rechaza IDs que intentan salirse de la ruta" do
    for bad <- ["../x", "1/2", "1?a=b", "", nil] do
      assert {:error, _} = Client.path(["accounts", bad])
    end
  end
end
