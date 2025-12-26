defmodule TicketSplitter.Tickets.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tickets" do
    field :image_url, :string
    field :products_json, :map
    field :total_participants, :integer, default: 0
    field :merchant_name, :string
    field :date, :date
    field :currency, :string, default: "EUR"
    field :total_amount, :decimal

    has_many :products, TicketSplitter.Tickets.Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [
      :image_url,
      :products_json,
      :total_participants,
      :merchant_name,
      :date,
      :currency,
      :total_amount
    ])
    |> validate_required([:total_participants])
    |> validate_number(:total_participants, greater_than_or_equal_to: 0)
    |> validate_number(:total_amount, greater_than_or_equal_to: 0)
  end
end
