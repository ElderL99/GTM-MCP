defmodule GtmMcp.AdminTest do
  use ExUnit.Case
  import Plug.Test
  import Plug.Conn

  setup do
    file = Path.join(System.tmp_dir!(), "gtm_admin_#{System.unique_integer([:positive])}.json")
    System.put_env("GTM_KEYS_FILE", file)
    on_exit(fn -> File.rm(file) end)
  end

  defp call(method, path, body \\ %{}, origin \\ "http://gtm.localhost:4101") do
    conn(method, path, body)
    |> Map.merge(%{host: "gtm.localhost", port: 4101})
    |> put_req_header("origin", origin)
    |> GtmMcp.Admin.call([])
  end

  test "crear muestra la key una vez y revocar la quita" do
    conn = call(:post, "/keys", %{"name" => "cursor"})
    assert conn.status == 201
    assert [key] = Regex.run(~r/gtm_[A-Za-z0-9_-]{43}/, conn.resp_body)
    assert get_resp_header(conn, "cache-control") == ["no-store"]

    refute call(:get, "/").resp_body =~ key
    assert call(:post, "/keys/revoke", %{"name" => "cursor"}).status == 303
    refute call(:get, "/").resp_body =~ "<td>cursor</td>"
  end

  test "rechaza nombres inválidos y escapa HTML" do
    conn = call(:post, "/keys", %{"name" => "<script>"})
    assert conn.status == 422
    refute conn.resp_body =~ "<script>"
  end

  test "bloquea POST desde otro origen y hosts ajenos" do
    assert call(:post, "/keys", %{"name" => "x"}, "https://evil.example").status == 403
    assert conn(:get, "/") |> Map.put(:host, "evil.example") |> GtmMcp.Admin.call([]) |> Map.get(:status) == 403
    assert GtmMcp.Keys.list() == []
  end
end
