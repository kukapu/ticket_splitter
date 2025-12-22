defmodule TicketSplitter.Repo.Migrations.AddParticipantConfigs do
  use Ecto.Migration

  def change do
    create table(:participant_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ticket_id, references(:tickets, type: :binary_id, on_delete: :delete_all), null: false
      add :participant_name, :string, null: false
      add :multiplier, :integer, default: 1, null: false

      timestamps(type: :utc_datetime)
    end

    # Cada participante solo puede tener una config por ticket
    create unique_index(:participant_configs, [:ticket_id, :participant_name])
    create index(:participant_configs, [:ticket_id])
  end
end
