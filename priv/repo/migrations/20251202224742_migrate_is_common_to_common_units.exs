defmodule TicketSplitter.Repo.Migrations.MigrateIsCommonToCommonUnits do
  use Ecto.Migration

  def up do
    # Update products where is_common = true
    # Set common_units = units (all units are common)
    execute """
    UPDATE products
    SET common_units = units::decimal,
        is_common = false
    WHERE is_common = true
    """
  end

  def down do
    # Revert: set is_common = true where common_units = units
    execute """
    UPDATE products
    SET is_common = true,
        common_units = 0
    WHERE common_units = units::decimal
    """
  end
end
