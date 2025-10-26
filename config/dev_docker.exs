import Config

# Configure your database for Docker
config :ticket_splitter, TicketSplitter.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "db",  # Nombre del contenedor Docker
  database: "ticket_splitter_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging. Code reloading disabled for Docker.
config :ticket_splitter, TicketSplitterWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: false,
  debug_errors: true,
  secret_key_base: System.get_env("SECRET_KEY_BASE") || "SECRET_KEY_BASE"

# Live reload disabled for Docker
# config :ticket_splitter, TicketSplitterWeb.Endpoint,
#   live_reload: [
#     patterns: [
#       ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
#       ~r"priv/gettext/.*(po)$",
#       ~r"lib/ticket_splitter_web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
#     ]
#   ]

# Enable dev routes for dashboard and mailbox
config :ticket_splitter, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# OpenRouter configuration
config :ticket_splitter,
  openrouter_api_key: System.get_env("OPENROUTER_API_KEY"),
  openrouter_model: System.get_env("OPENROUTER_MODEL") || "openai/gpt-4o"
