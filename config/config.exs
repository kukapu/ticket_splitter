# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ticket_splitter,
  ecto_repos: [TicketSplitter.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :ticket_splitter, TicketSplitterWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TicketSplitterWeb.ErrorHTML, json: TicketSplitterWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TicketSplitter.PubSub,
  live_view: [signing_salt: "pV3ChVfY"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :ticket_splitter, TicketSplitter.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  ticket_splitter: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (uses npm-installed version)
config :tailwind,
  ticket_splitter: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# S3/MinIO Configuration (base settings, overridden per environment)
config :ex_aws,
  json_codec: Jason,
  access_key_id: System.get_env("MINIO_ACCESS_KEY") || "minioadmin",
  secret_access_key: System.get_env("MINIO_SECRET_KEY") || "minioadmin"

config :ex_aws, :s3,
  scheme: System.get_env("MINIO_SCHEME") || "http",
  host: System.get_env("MINIO_HOST") || "localhost",
  port: String.to_integer(System.get_env("MINIO_PORT") || "9000"),
  region: System.get_env("MINIO_REGION") || "us-east-1"

config :ticket_splitter, :storage,
  bucket: System.get_env("MINIO_BUCKET") || "ticket-splitter",
  public_url: System.get_env("MINIO_PUBLIC_URL") || "http://localhost:9000/ticket-splitter"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
