defmodule GtmMcp.KeysTest do
  use ExUnit.Case
  alias GtmMcp.Keys

  setup do
    file = Path.join(System.tmp_dir!(), "gtm_keys_#{System.unique_integer([:positive])}.json")
    System.put_env("GTM_KEYS_FILE", file)
    on_exit(fn -> File.rm(file) end)
    %{keys_file: file}
  end

  test "crear, validar y revocar una key", %{keys_file: file} do
    config = %{resource: "gtm-mcp"}
    {:ok, key} = Keys.create("cursor")

    refute File.read!(file) =~ key, "la key en claro no debe guardarse"
    assert {:ok, %{"sub" => "cursor"}} = Keys.validate_token(key, config)
    assert {:error, _} = Keys.validate_token("gtm_falsa", config)
    assert {:error, _} = Keys.create("cursor")

    :ok = Keys.revoke("cursor")
    assert {:error, _} = Keys.validate_token(key, config)
  end
end
