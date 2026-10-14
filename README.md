# GTM MCP

Servidor MCP en Elixir para que agentes de IA consulten Google Tag Manager
sin depender de servicios de terceros.

## Objetivo

Dar a los agentes de IA (Claude Code, Cursor o cualquier cliente MCP) acceso
a la configuración de Google Tag Manager, con tres principios:

1. **Sin intermediarios.** El servidor corre en tu infraestructura y habla
   directo con la API oficial de Google (Tag Manager API v2). Ningún tercero
   ve tus contenedores, tags ni credenciales.
2. **Seguro por defecto.** Solo lectura (scope `tagmanager.readonly`): el
   agente puede auditar y explicar la configuración, pero no puede modificar
   ni publicar nada.
3. **Acceso controlado por agente.** Cada agente se conecta con su propia
   API key, que se puede revocar en cualquier momento desde una UI local.

Casos de uso: auditar contenedores, documentar qué tags y triggers existen,
comparar versiones publicadas y responder preguntas sobre la medición de un
sitio sin entrar a la consola de GTM.

## Cómo funciona

```
Agente ──MCP──▶ GTM MCP (Elixir) ──HTTPS──▶ Google Tag Manager API v2
                    │
                    └── cuenta de servicio de Google (solo lectura)
```

El servidor tiene dos modos de transporte:

| Modo | Para qué | Autenticación |
|---|---|---|
| `stdio` (por defecto) | Un agente local lo arranca como proceso hijo | No necesita (es local) |
| `http` | Cualquier agente se conecta por red | API key por agente |

## Herramientas

| Herramienta | Parámetros |
|---|---|
| `gtm_list_accounts` | — |
| `gtm_list_containers` | `account_id` |
| `gtm_list_workspaces` | `account_id`, `container_id` |
| `gtm_list_workspace_items` | `account_id`, `container_id`, `workspace_id`, `kind`: tags · triggers · variables · built_in_variables · folders · templates · clients · zones · transformations |
| `gtm_list_versions` | `account_id`, `container_id` |
| `gtm_get_version` | `account_id`, `container_id`, `version_id` o `"live"` |

## Cómo levantarlo

### Paso 1 · Instalar Elixir

Se necesita Elixir 1.20+ con Erlang/OTP 29+. En macOS:

```sh
brew install elixir
elixir --version
```

### Paso 2 · Descargar y compilar el proyecto

```sh
git clone https://github.com/ElderL99/GTM-MCP.git
cd GTM-MCP
mix deps.get
MIX_ENV=prod mix release
```

El ejecutable queda en `_build/prod/rel/gtm_mcp/bin/gtm_mcp`.

### Paso 3 · Conseguir la llave de Google

1. En Google Cloud Console, crea (o elige) un proyecto y activa la
   **Tag Manager API**.
2. Crea una **cuenta de servicio** y descarga su llave en formato JSON.
3. En Google Tag Manager, agrega el correo de la cuenta de servicio
   (`...@...iam.gserviceaccount.com`) como usuario de los contenedores,
   con permiso de **lectura**.
4. Guarda la llave y protégela:

   ```sh
   mkdir -p ~/.config/gtm-mcp
   mv ~/Downloads/<llave>.json ~/.config/gtm-mcp/service-account.json
   chmod 600 ~/.config/gtm-mcp/service-account.json
   ```

Sin la llave el servidor arranca igual, pero las herramientas de GTM
responden con un error indicando que falta.

### Paso 4 · Elegir el modo y arrancarlo

**Opción A · stdio (un agente en la misma máquina).** No hay que arrancar
nada a mano: el agente lanza el servidor cuando lo necesita. Con Claude Code:

```sh
claude mcp add --scope user gtm -- $PWD/_build/prod/rel/gtm_mcp/bin/gtm_mcp start
```

**Opción B · HTTP (cualquier agente, con API keys).**

1. Arranca el servidor y déjalo corriendo:

   ```sh
   GTM_TRANSPORT=http _build/prod/rel/gtm_mcp/bin/gtm_mcp start
   ```

2. Abre la UI local **http://gtm.localhost:4101** y crea una key por agente.
   También se puede desde la terminal:

   ```sh
   mix gtm.keys create cursor
   mix gtm.keys list
   mix gtm.keys revoke cursor
   ```

   La key se muestra una sola vez. Solo se guarda su hash SHA-256 en
   `~/.config/gtm-mcp/api_keys.json`.

3. Configura el agente con la URL `http://127.0.0.1:4100/mcp` y el header
   `Authorization: Bearer <key>`. Ejemplo con Claude Code:

   ```sh
   claude mcp add --transport http gtm-http http://127.0.0.1:4100/mcp \
     --header "Authorization: Bearer gtm_..."
   ```

### Paso 5 · Verificar que funciona

1. En Claude Code, escribe `/mcp`: el servidor debe aparecer como conectado.
2. Pide al agente: *"lista mis cuentas de GTM"*. Si responde con tus
   cuentas, todo está listo.
3. Si responde `falta la llave de Google`, revisa el paso 3. Si responde
   `GTM API 403`, la cuenta de servicio no tiene acceso al contenedor en GTM.

### Si cambias el código

Vuelve a compilar el ejecutable para que los agentes usen la versión nueva:

```sh
MIX_ENV=prod mix release --overwrite
```

## Configuración

| Variable | Por defecto | Descripción |
|---|---|---|
| `GTM_TRANSPORT` | `stdio` | `stdio` o `http` |
| `GTM_CREDENTIALS` | `~/.config/gtm-mcp/service-account.json` | Llave de la cuenta de servicio |
| `GTM_KEYS_FILE` | `~/.config/gtm-mcp/api_keys.json` | Hashes de las API keys |
| `GTM_HTTP_IP` | `127.0.0.1` | IP del endpoint MCP |
| `GTM_HTTP_PORT` | `4100` | Puerto del endpoint MCP |
| `GTM_ADMIN_PORT` | `4101` | Puerto de la UI de keys (siempre en 127.0.0.1) |

## Seguridad

- La UI de administración solo escucha en `127.0.0.1` y valida los headers
  `Host` y `Origin` para bloquear DNS rebinding y formularios de otros sitios.
- Los IDs que recibe el agente se validan antes de construir rutas a la API.
- HTTP/2 está desactivado por EEF-CVE-2026-105659 (sin parche en bandit 1.12.5).
- Para exponer el endpoint MCP fuera de la máquina, pon TLS delante
  (Caddy, nginx).
- Todas las API keys comparten el acceso de la misma cuenta de servicio.

## Pruebas

```sh
mix test --no-start
```

## Licencia

[MIT](LICENSE). Las dependencias conservan sus propias licencias
(por ejemplo, `anubis_mcp` es LGPL-3.0).
