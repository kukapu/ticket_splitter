defmodule TicketSplitter.Tickets.ParticipantConfig do
  @moduledoc """
  Schema for participant configuration per ticket.

  Stores additional settings for each participant, such as their multiplier
  (how many people they're paying for).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "participant_configs" do
    field :participant_name, :string
    field :multiplier, :integer, default: 1

    belongs_to :ticket, TicketSplitter.Tickets.Ticket

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:ticket_id, :participant_name, :multiplier])
    |> validate_required([:ticket_id, :participant_name])
    |> validate_number(:multiplier, greater_than: 0, less_than_or_equal_to: 10)
    |> unique_constraint([:ticket_id, :participant_name])
    |> foreign_key_constraint(:ticket_id)
  end
end
