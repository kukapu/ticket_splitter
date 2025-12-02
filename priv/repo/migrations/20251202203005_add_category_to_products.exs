defmodule TicketSplitter.Repo.Migrations.AddCategoryToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :category, :string
    end

    # Crear índice para poder filtrar/ordenar por categoría eficientemente
    create index(:products, [:category])
  end
end
