defmodule TicketSplitter.Repo.Migrations.AddPositionToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :position, :integer, default: 0
    end

    # Populate position field based on current order (inserted_at)
    execute """
      UPDATE products
      SET position = (
        SELECT row_number - 1
        FROM (
          SELECT id, row_number() OVER (ORDER BY inserted_at) as row_number
          FROM products
        ) as numbered_products
        WHERE numbered_products.id = products.id
      )
    """

    create index(:products, [:ticket_id, :position])
  end
end
