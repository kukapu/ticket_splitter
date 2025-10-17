defmodule TicketSplitter.Tickets.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tickets" do
    field :image_url, :string
    field :products_json, :map
    field :total_participants, :integer, default: 1

    has_many :products, TicketSplitter.Tickets.Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:image_url, :products_json, :total_participants])
    |> validate_required([:total_participants])
    |> validate_number(:total_participants, greater_than: 0)
  end
end
