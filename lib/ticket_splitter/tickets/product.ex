defmodule TicketSplitter.Tickets.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "products" do
    field :name, :string
    field :units, :integer
    field :unit_price, :decimal
    field :total_price, :decimal
    field :confidence, :decimal
    field :is_common, :boolean, default: false
    field :common_units, :decimal, default: 0.0
    field :position, :integer, default: 0
    field :category, :string

    belongs_to :ticket, TicketSplitter.Tickets.Ticket
    has_many :participant_assignments, TicketSplitter.Tickets.ParticipantAssignment

    timestamps(type: :utc_datetime)
  end

  @categories ~w(DRINK STARTER MAIN DESSERT OTHER)

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :ticket_id,
      :name,
      :units,
      :unit_price,
      :total_price,
      :confidence,
      :is_common,
      :common_units,
      :position,
      :category
    ])
    |> validate_required([:ticket_id, :name, :units, :unit_price, :total_price])
    |> validate_number(:units, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> validate_number(:total_price, greater_than_or_equal_to: 0)
    |> validate_inclusion(:category, @categories)
    |> foreign_key_constraint(:ticket_id)
  end
end
