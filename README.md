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

## Requisitos

- Elixir 1.20+ / Erlang OTP 29+
- Una cuenta de servicio de Google Cloud con la Tag Manager API activada,
  agregada como usuario (lectura) en los contenedores de GTM.

## Instalación

```sh
mix deps.get
MIX_ENV=prod mix release
```

Guarda la llave JSON de la cuenta de servicio en
`~/.config/gtm-mcp/service-account.json` (o indica otra ruta con
`GTM_CREDENTIALS`) y protégela con `chmod 600`.

Sin la llave el servidor arranca igual; las herramientas de GTM responden
con un error indicando que falta.

## Uso en modo stdio

```sh
claude mcp add --scope user gtm -- $PWD/_build/prod/rel/gtm_mcp/bin/gtm_mcp start
```

## Uso en modo HTTP con API keys

1. Levanta el servidor:

   ```sh
   GTM_TRANSPORT=http _build/prod/rel/gtm_mcp/bin/gtm_mcp start
   ```

2. Crea una key por agente en la UI local **http://gtm.localhost:4101**, o
   desde la terminal:

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
