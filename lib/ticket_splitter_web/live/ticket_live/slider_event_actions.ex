defmodule TicketSplitterWeb.TicketLive.SliderEventActions do
  @moduledoc """
  Módulo que contiene funciones para manejar eventos de sliders vía handle_event.
  """

  alias TicketSplitter.Tickets
  alias TicketSplitter.Tickets.TicketBroadcaster
  alias TicketSplitterWeb.TicketLive.SliderActions

  @doc """
  Ejecuta la actualización de porcentajes de split y retorna el resultado.
  """
  def execute_split_percentage_update(ticket_id, group_id, p1_percentage, p2_percentage) do
    case SliderActions.update_split_percentages(group_id, p1_percentage, p2_percentage) do
      :ok ->
        TicketBroadcaster.broadcast_ticket_update(ticket_id)
        {:ok, Tickets.get_ticket_with_products!(ticket_id)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Ejecuta el guardado de porcentajes personalizados.
  """
  def execute_save_percentages(ticket_id, assignments_map) do
    updates = SliderActions.parse_percentage_updates(assignments_map)
    SliderActions.update_custom_percentages(updates)

    TicketBroadcaster.broadcast_ticket_update(ticket_id)
    {:ok, Tickets.get_ticket_with_products!(ticket_id)}
  end

  @doc """
  Construye assigns después de guardar porcentajes.
  """
  def build_save_percentages_assigns(ticket) do
    [
      ticket: ticket,
      products: ticket.products,
      editing_percentages_product_id: nil
    ]
  end

  @doc """
  Construye assigns para actualizar el acting_as_total si está en modo acting_as.
  """
  def build_acting_as_total_assigns(ticket_id, acting_as_participant) do
    if acting_as_participant do
      acting_as_total =
        Tickets.calculate_participant_total_with_multiplier(ticket_id, acting_as_participant)

      [acting_as_total: acting_as_total]
    else
      []
    end
  end
end
