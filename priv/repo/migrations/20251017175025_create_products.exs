defmodule TicketSplitter.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ticket_id, references(:tickets, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false
      add :units, :integer, null: false
      add :unit_price, :decimal, precision: 10, scale: 2, null: false
      add :total_price, :decimal, precision: 10, scale: 2, null: false
      add :confidence, :decimal, precision: 3, scale: 2
      add :is_common, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:products, [:ticket_id])
  end
end
