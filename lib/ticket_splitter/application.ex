defmodule TicketSplitter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TicketSplitterWeb.Telemetry,
      TicketSplitter.Repo,
      {DNSCluster, query: Application.get_env(:ticket_splitter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TicketSplitter.PubSub},
      # Start a worker by calling: TicketSplitter.Worker.start_link(arg)
      # {TicketSplitter.Worker, arg},
      # Start to serve requests, typically the last entry
      TicketSplitterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TicketSplitter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TicketSplitterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
