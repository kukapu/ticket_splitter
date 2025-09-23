defmodule TicketSplitter.Repo do
  use Ecto.Repo,
    otp_app: :ticket_splitter,
    adapter: Ecto.Adapters.Postgres
end
