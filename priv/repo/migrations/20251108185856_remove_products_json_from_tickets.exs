defmodule TicketSplitter.Repo.Migrations.RemoveProductsJsonFromTickets do
  use Ecto.Migration

  def change do
    alter table(:tickets) do
      remove :products_json
    end
  end
end
