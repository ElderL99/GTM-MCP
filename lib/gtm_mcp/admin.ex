defmodule GtmMcp.Admin do
  @moduledoc """
  UI local para gestionar las API keys (http://gtm.localhost:4101).

  Solo escucha en 127.0.0.1. Además valida `Host` (contra DNS rebinding)
  y `Origin` en los POST (contra formularios enviados desde otros sitios).
  """
  use Plug.Router
  alias GtmMcp.Keys

  plug :check_host
  plug :match
  plug Plug.Parsers, parsers: [:urlencoded]
  plug :check_origin
  plug :dispatch

  get "/" do
    page(conn, 200, notice: conn.query_params["ok"])
  end

  post "/keys" do
    case Keys.create(conn.body_params["name"]) do
      {:ok, key} -> page(conn, 201, new_key: {conn.body_params["name"], key})
      {:error, msg} -> page(conn, 422, error: msg)
    end
  end

  post "/keys/revoke" do
    case Keys.revoke(conn.body_params["name"]) do
      :ok -> conn |> put_resp_header("location", "/?ok=revocada") |> send_resp(303, "")
      {:error, msg} -> page(conn, 404, error: msg)
    end
  end

  match _ do
    send_resp(conn, 404, "No encontrado")
  end

  defp check_host(conn, _) do
    if conn.host in ["localhost", "127.0.0.1"] or String.ends_with?(conn.host, ".localhost"),
      do: conn,
      else: conn |> send_resp(403, "Host no permitido") |> halt()
  end

  defp check_origin(%{method: "POST"} = conn, _) do
    origin = conn |> get_req_header("origin") |> List.first()

    if origin == "#{conn.scheme}://#{conn.host}:#{conn.port}",
      do: conn,
      else: conn |> send_resp(403, "Origen no permitido") |> halt()
  end

  defp check_origin(conn, _), do: conn

  defp page(conn, status, opts) do
    conn
    |> put_resp_content_type("text/html")
    # La página puede mostrar una key recién creada: que el navegador no la guarde.
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(status, render(keys: Keys.list(), mcp_url: mcp_url(conn), opts: opts))
  end

  defp mcp_url(conn), do: "http://#{conn.host}:#{System.get_env("GTM_HTTP_PORT", "4100")}/mcp"

  defp h(value), do: value |> to_string() |> Plug.HTML.html_escape()

  require EEx

  EEx.function_from_string(:defp, :render, ~S"""
  <!doctype html>
  <html lang="es">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>GTM MCP · API keys</title>
    <style>
      :root { --bg:#fafafa; --fg:#1a1a1a; --muted:#666; --card:#fff; --line:#ddd;
              --accent:#2563eb; --danger:#b91c1c; --ok-bg:#ecfdf5; --ok-line:#059669;
              --err-bg:#fef2f2; color-scheme: light dark; }
      @media (prefers-color-scheme: dark) {
        :root { --bg:#111; --fg:#eee; --muted:#aaa; --card:#1b1b1b; --line:#333;
                --accent:#60a5fa; --danger:#f87171; --ok-bg:#062e22; --err-bg:#3a1212; }
      }
      * { box-sizing: border-box; }
      body { margin:0; background:var(--bg); color:var(--fg);
             font:16px/1.5 system-ui, -apple-system, sans-serif; }
      main { max-width:720px; margin:0 auto; padding:32px 16px; }
      h1 { font-size:1.5rem; margin:0 0 4px; }
      h2 { font-size:1.1rem; margin:0 0 12px; }
      p.sub { color:var(--muted); margin:0 0 24px; }
      section { background:var(--card); border:1px solid var(--line); border-radius:8px;
                padding:20px; margin-bottom:20px; }
      label { display:block; font-weight:600; margin-bottom:6px; }
      .row { display:flex; gap:8px; flex-wrap:wrap; }
      input[type=text] { flex:1; min-width:180px; padding:10px; font:inherit;
                         border:1px solid var(--line); border-radius:6px;
                         background:var(--bg); color:var(--fg); }
      button { padding:10px 16px; font:inherit; border-radius:6px; cursor:pointer;
               border:1px solid var(--accent); background:var(--accent); color:#fff; }
      button.danger { background:transparent; color:var(--danger); border-color:var(--danger);
                      padding:6px 12px; }
      button:focus-visible, input:focus-visible { outline:3px solid var(--accent); outline-offset:2px; }
      .hint { color:var(--muted); font-size:.9rem; margin:6px 0 0; }
      .box { border-radius:6px; padding:14px; margin-bottom:20px; border:1px solid; }
      .ok { background:var(--ok-bg); border-color:var(--ok-line); }
      .err { background:var(--err-bg); border-color:var(--danger); }
      code { font-family:ui-monospace, Menlo, monospace; word-break:break-all; }
      .key { display:block; padding:10px; margin:8px 0; background:var(--bg);
             border:1px solid var(--line); border-radius:6px; }
      table { width:100%; border-collapse:collapse; }
      th, td { text-align:left; padding:10px 6px; border-bottom:1px solid var(--line); }
      th { font-size:.85rem; color:var(--muted); font-weight:600; }
      td.act { text-align:right; }
      .empty { color:var(--muted); }
    </style>
  </head>
  <body>
  <main>
    <h1>API keys · GTM MCP</h1>
    <p class="sub">Cada agente se conecta con su propia key. Revocar una key la desactiva al instante.</p>

    <%= if @opts[:notice] == "revocada" do %>
      <div class="box ok" role="status">Key revocada.</div>
    <% end %>

    <%= if @opts[:error] do %>
      <div class="box err" role="alert"><%= h(@opts[:error]) %></div>
    <% end %>

    <%= if @opts[:new_key] do %>
      <% {name, key} = @opts[:new_key] %>
      <div class="box ok" role="status">
        <strong>Key creada para «<%= h(name) %>».</strong>
        Cópiala ahora: <strong>no se vuelve a mostrar</strong>.
        <code class="key" id="new-key"><%= h(key) %></code>
        <button type="button" onclick="navigator.clipboard.writeText(document.getElementById('new-key').textContent).then(()=>this.textContent='Copiada ✓')">Copiar key</button>
        <p class="hint">En el agente usa la URL <code><%= h(@mcp_url) %></code> y el header
        <code>Authorization: Bearer &lt;key&gt;</code>.</p>
      </div>
    <% end %>

    <section>
      <h2>Crear key</h2>
      <form method="post" action="/keys">
        <label for="name">Nombre del agente</label>
        <div class="row">
          <input type="text" id="name" name="name" required maxlength="40"
                 pattern="[A-Za-z0-9_\-]+" placeholder="por ejemplo: cursor" autocomplete="off">
          <button type="submit">Crear</button>
        </div>
        <p class="hint">Solo letras, números, - y _. Máximo 40 caracteres.</p>
      </form>
    </section>

    <section>
      <h2>Keys activas (<%= length(@keys) %>)</h2>
      <%= if @keys == [] do %>
        <p class="empty">Todavía no hay keys.</p>
      <% else %>
        <table>
          <thead><tr><th scope="col">Nombre</th><th scope="col">Creada (UTC)</th><th scope="col"><span hidden>Acción</span></th></tr></thead>
          <tbody>
          <%= for k <- @keys do %>
            <tr>
              <td><%= h(k["name"]) %></td>
              <td><%= h(String.slice(k["created_at"], 0, 16) |> String.replace("T", " ")) %></td>
              <td class="act">
                <form method="post" action="/keys/revoke"
                      onsubmit="return confirm('¿Revocar la key «<%= h(k["name"]) %>»? El agente perderá el acceso.')">
                  <input type="hidden" name="name" value="<%= h(k["name"]) %>">
                  <button type="submit" class="danger">Revocar</button>
                </form>
              </td>
            </tr>
          <% end %>
          </tbody>
        </table>
      <% end %>
    </section>
  </main>
  </body>
  </html>
  """, [:assigns])
end
