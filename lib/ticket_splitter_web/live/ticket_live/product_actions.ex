defmodule TicketSplitterWeb.TicketLive.ProductActions do
  @moduledoc """
  Módulo que contiene funciones puras para gestionar acciones relacionadas con productos.
  """

  alias TicketSplitter.Tickets
  alias TicketSplitter.Tickets.TicketBroadcaster

  @doc """
  Ejecuta una acción de producto y actualiza el socket.
  La función de acción debe recibir el product_id y devolver {:ok, _} o {:error, _}.
  """
  def execute_product_action(ticket_id, product_id, action_fn) do
    case action_fn.(product_id) do
      {:ok, _} ->
        TicketBroadcaster.broadcast_ticket_update(ticket_id)
        {:ok, Tickets.get_ticket_with_products!(ticket_id)}

      {:error, _} ->
        {:error}
    end
  end

  @doc """
  Ejecuta una acción de producto y actualiza el socket (versión con producto).
  """
  def execute_product_action_with_product(ticket_id, product_id, action_fn) do
    product = Tickets.get_product!(product_id)

    case action_fn.(product) do
      {:ok, _} ->
        TicketBroadcaster.broadcast_ticket_update(ticket_id)
        {:ok, Tickets.get_ticket_with_products!(ticket_id)}

      {:error, _} ->
        {:error}
    end
  end

  @doc """
  Toggle producto como común.
  """
  def toggle_common(ticket_id, product_id) do
    execute_product_action_with_product(ticket_id, product_id, &Tickets.toggle_product_common/1)
  end

  @doc """
  Añade unidades al pool común.
  """
  def add_common_units(ticket_id, product_id, count \\ 1) do
    execute_product_action(ticket_id, product_id, fn pid -> Tickets.add_common_units(pid, count) end)
  end

  @doc """
  Elimina el producto del pool común.
  """
  def remove_from_common(ticket_id, product_id) do
    execute_product_action_with_product(ticket_id, product_id, &Tickets.make_product_not_common/1)
  end

  @doc """
  Elimina unidades del pool común.
  """
  def remove_common_units(ticket_id, product_id, count \\ 1) do
    execute_product_action(ticket_id, product_id, fn pid -> Tickets.remove_common_units(pid, count) end)
  end

  @doc """
  Convierte el resultado de una acción de producto en assigns.
  """
  def result_to_assigns(result) do
    case result do
      {:ok, ticket} ->
        [ticket: ticket, products: ticket.products]

      {:error} ->
        []
    end
  end
end
