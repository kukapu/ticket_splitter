defmodule TicketSplitter.Repo.Migrations.CreateParticipantAssignments do
  use Ecto.Migration

  def change do
    create table(:participant_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :product_id, references(:products, on_delete: :delete_all, type: :binary_id),
        null: false

      add :participant_name, :string, null: false
      add :percentage, :decimal, precision: 5, scale: 2, default: 0.0
      add :assigned_color, :string

      timestamps(type: :utc_datetime)
    end

    create index(:participant_assignments, [:product_id])
    create index(:participant_assignments, [:participant_name])
  end
end
