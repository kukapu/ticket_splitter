defmodule TicketSplitter.Repo.Migrations.AddUnitsAssignedToParticipantAssignments do
  use Ecto.Migration

  def change do
    alter table(:participant_assignments) do
      add :units_assigned, :decimal, precision: 10, scale: 2, default: 0.0
    end
  end
end
