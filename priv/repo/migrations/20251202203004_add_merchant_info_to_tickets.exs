defmodule TicketSplitter.Repo.Migrations.AddMerchantInfoToTickets do
  use Ecto.Migration

  def change do
    alter table(:tickets) do
      add :merchant_name, :string
      add :date, :date
      add :currency, :string, default: "EUR"
      add :total_amount, :decimal, precision: 10, scale: 2
    end
  end
end
