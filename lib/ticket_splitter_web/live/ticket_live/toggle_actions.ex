defmodule TicketSplitterWeb.TicketLive.ToggleActions do
  @moduledoc """
  Módulo que contiene funciones para ejecutar acciones de toggle en productos.
  """

  alias TicketSplitter.Tickets

  @doc """
  Ejecuta una acción de toggle basada en el tipo de acción.
  """
  def execute_action(action, product_id, participant_name, color, params) do
    case action do
      "add_unit" ->
        Tickets.add_participant_unit(product_id, participant_name, color)

      "remove_unit" ->
        group_id = Map.get(params, "group_id")
        Tickets.remove_participant_unit(product_id, participant_name, group_id)

      "join_group" ->
        group_id = Map.get(params, "group_id")
        Tickets.join_assignment_group(group_id, participant_name, color)

      _ ->
        {:error, :invalid_action}
    end
  end

  @doc """
  Determina si se debe contar participantes antes de la acción.
  """
  def should_count_participants_before?(action) do
    action in ["add_unit", "join_group"]
  end

  @doc """
  Verifica si se añadió un nuevo participante comparando conteos.
  """
  def new_participant_added?(count_before, count_after) do
    count_before && count_after > count_before
  end

  @doc """
  Actualiza el total de participantes si se añadió uno nuevo.
  DEPRECATED: Now handled by ParticipantConfig system. This is a no-op.
  """
  def update_total_if_new_participant(
        _socket,
        _participant_count_before,
        _real_participants_count,
        ticket
      ) do
    # No-op: total_participants now managed via ParticipantConfig
    # Participants added via set_participant_name, not product assignments
    {:ok, ticket}
  end

  @doc """
  Recalcula el acting_as_total si está en modo acting_as.
  """
  def recalculate_acting_as_total(ticket_id, acting_as_participant) do
    Tickets.calculate_participant_total_with_multiplier(ticket_id, acting_as_participant)
  end
end
