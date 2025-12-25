defmodule TicketSplitterWeb.TicketLive.SliderActions do
  @moduledoc """
  Módulo consolidado que contiene todas las funciones para gestionar sliders.
  Incluye bloqueos, actualizaciones de porcentajes, handle_info y handle_event.
  """

  alias TicketSplitter.Tickets
  alias TicketSplitter.Tickets.TicketBroadcaster

  # ============================================================================
  # Funciones de bloqueo de sliders
  # ============================================================================

  @doc """
  Determina si el usuario activo tiene el bloqueo del slider.
  """
  def has_lock?(locked_sliders, group_id, active_participant) do
    Map.get(locked_sliders, group_id) == active_participant
  end

  @doc """
  Determina si el slider puede ser bloqueado por el usuario activo.
  """
  def can_acquire_lock?(locked_sliders, group_id, active_participant) do
    case Map.get(locked_sliders, group_id) do
      nil -> true
      ^active_participant -> :already_locked
      _other_user -> false
    end
  end

  @doc """
  Actualiza el mapa de sliders bloqueados adquiriendo un bloqueo.
  """
  def acquire_lock(locked_sliders, group_id, active_participant) do
    Map.put(locked_sliders, group_id, active_participant)
  end

  @doc """
  Actualiza el mapa de sliders bloqueados liberando un bloqueo.
  """
  def release_lock(locked_sliders, group_id, active_participant) do
    locked_by = Map.get(locked_sliders, group_id)

    if locked_by == active_participant do
      Map.delete(locked_sliders, group_id)
    else
      locked_sliders
    end
  end

  # ============================================================================
  # Funciones de actualización de porcentajes
  # ============================================================================

  @doc """
  Convierte el mapa de asignaciones a una lista de actualizaciones.
  """
  def parse_percentage_updates(assignments_map) do
    Enum.map(assignments_map, fn {assignment_id, percentage_str} ->
      {percentage, _} = Float.parse(percentage_str)
      {assignment_id, Decimal.new(to_string(percentage))}
    end)
  end

  @doc """
  Actualiza los porcentajes de división en un grupo.
  """
  def update_split_percentages(group_id, p1_percentage, p2_percentage) do
    Tickets.update_split_percentages(group_id, p1_percentage, p2_percentage)
  end

  @doc """
  Actualiza porcentajes personalizados.
  """
  def update_custom_percentages(updates) do
    Tickets.update_custom_percentages(updates)
  end

  # ============================================================================
  # Funciones de handle_info (assigns para sliders)
  # ============================================================================

  @doc """
  Construye assigns cuando un slider es bloqueado.
  """
  def slider_locked_assigns(locked_sliders, group_id, locked_by) do
    [locked_sliders: Map.put(locked_sliders, group_id, locked_by)]
  end

  @doc """
  Construye assigns cuando un slider es desbloqueado.
  """
  def slider_unlocked_assigns(locked_sliders, group_id) do
    [locked_sliders: Map.delete(locked_sliders, group_id)]
  end

  # ============================================================================
  # Funciones de handle_event (ejecución de actualizaciones)
  # ============================================================================

  @doc """
  Ejecuta la actualización de porcentajes de split y retorna el resultado.
  """
  def execute_split_percentage_update(ticket_id, group_id, p1_percentage, p2_percentage) do
    case update_split_percentages(group_id, p1_percentage, p2_percentage) do
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
    updates = parse_percentage_updates(assignments_map)
    update_custom_percentages(updates)

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
