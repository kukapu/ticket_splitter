defmodule TicketSplitter.Tickets.Contexts.ProductOperations do
  @moduledoc """
  Operations for Product CRUD and product-specific operations (common units, etc).
  """

  import Ecto.Query, warn: false
  alias TicketSplitter.Repo
  alias TicketSplitter.Tickets.Product

  @doc """
  Returns the list of products for a ticket.
  """
  def list_products_by_ticket(ticket_id) do
    Product
    |> where([p], p.ticket_id == ^ticket_id)
    |> Repo.all()
  end

  @doc """
  Gets a single product.
  """
  def get_product!(id), do: Repo.get!(Product, id)

  @doc """
  Gets a single product with preloaded participant assignments.
  """
  def get_product_with_assignments!(id) do
    Product
    |> Repo.get!(id)
    |> Repo.preload(:participant_assignments)
  end

  @doc """
  Creates a product.
  """
  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a product.
  """
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a product.
  """
  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  @doc """
  Toggles the is_common flag on a product.
  """
  def toggle_product_common(%Product{} = product) do
    update_product(product, %{is_common: !product.is_common})
  end

  @doc """
  Makes a product common if it has no assignments.
  Returns error if product already has participant assignments.
  """
  def make_product_common(%Product{} = product) do
    # Use the main context for this cross-context call
    assignments = TicketSplitter.Tickets.list_assignments_by_product(product.id)

    if length(assignments) == 0 do
      update_product(product, %{is_common: true})
    else
      {:error, :has_assignments}
    end
  end

  @doc """
  Makes a product not common (removes from common status).
  """
  def make_product_not_common(%Product{} = product) do
    update_product(product, %{is_common: false})
  end

  @doc """
  Adds units to the common pool for a product.
  """
  def add_common_units(product_id, units_to_add \\ 1) do
    IO.puts("🟢 add_common_units called: product_id=#{product_id}, units_to_add=#{units_to_add}")
    product = get_product!(product_id)

    # Calculate available units (use main context for cross-context call)
    total_assigned = TicketSplitter.Tickets.get_total_assigned_units(product_id)
    current_common = product.common_units || Decimal.new("0")

    available =
      Decimal.sub(Decimal.new(product.units), Decimal.add(total_assigned, current_common))

    IO.puts(
      "  Available: #{available}, Current common: #{current_common}, Total assigned: #{total_assigned}"
    )

    units_decimal = Decimal.new(units_to_add)

    # Check if enough available
    result =
      if Decimal.compare(available, units_decimal) in [:gt, :eq] do
        new_common = Decimal.add(current_common, units_decimal)
        IO.puts("  ✅ Adding units. New common: #{new_common}")
        update_product(product, %{common_units: new_common})
      else
        IO.puts("  ❌ Not enough units available")
        {:error, :not_enough_units}
      end

    IO.inspect(result, label: "  Result")
    result
  end

  @doc """
  Removes units from the common pool for a product.
  """
  def remove_common_units(product_id, units_to_remove \\ 1) do
    product = get_product!(product_id)
    current_common = product.common_units || Decimal.new("0")
    units_decimal = Decimal.new(units_to_remove)

    if Decimal.compare(current_common, units_decimal) in [:gt, :eq] do
      new_common = Decimal.sub(current_common, units_decimal)
      update_product(product, %{common_units: new_common})
    else
      {:error, :not_enough_common_units}
    end
  end

  @doc """
  Gets available (unassigned and non-common) units for a product.
  """
  def get_available_units(product_id) do
    product = get_product!(product_id)
    # Use main context for cross-context call
    total_assigned = TicketSplitter.Tickets.get_total_assigned_units(product_id)
    common_units = product.common_units || Decimal.new("0")

    Decimal.new(product.units)
    |> Decimal.sub(total_assigned)
    |> Decimal.sub(common_units)
  end
end
