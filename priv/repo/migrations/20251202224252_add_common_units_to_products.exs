defmodule TicketSplitter.Repo.Migrations.AddCommonUnitsToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :common_units, :decimal, precision: 10, scale: 2, default: 0.0
    end
  end
end
