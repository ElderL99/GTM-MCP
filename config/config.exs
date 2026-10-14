import Config

# stdout es el canal MCP: cualquier log ahí rompe el protocolo.
config :logger, :default_handler, config: [type: :standard_error]
