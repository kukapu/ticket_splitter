defmodule TicketSplitter.Repo.Migrations.AddAssignmentGroupToParticipantAssignments do
  use Ecto.Migration

  def change do
    alter table(:participant_assignments) do
      add :assignment_group_id, :binary_id
    end

    create index(:participant_assignments, [:assignment_group_id])
  end
end
