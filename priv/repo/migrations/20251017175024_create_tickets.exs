defmodule TicketSplitter.Repo.Migrations.CreateTickets do
  use Ecto.Migration

  def change do
    create table(:tickets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :image_url, :string
      add :products_json, :jsonb
      add :total_participants, :integer, default: 1

      timestamps(type: :utc_datetime)
    end
  end
end
