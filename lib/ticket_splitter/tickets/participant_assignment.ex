defmodule TicketSplitter.Tickets.ParticipantAssignment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "participant_assignments" do
    field :participant_name, :string
    field :percentage, :decimal
    field :assigned_color, :string

    belongs_to :product, TicketSplitter.Tickets.Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(participant_assignment, attrs) do
    participant_assignment
    |> cast(attrs, [:product_id, :participant_name, :percentage, :assigned_color])
    |> validate_required([:product_id, :participant_name, :percentage])
    |> validate_number(:percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:product_id)
  end
end
