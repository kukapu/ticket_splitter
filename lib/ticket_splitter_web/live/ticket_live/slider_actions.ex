defmodule TicketSplitterWeb.TicketLive.SliderActions do
  @moduledoc """
  Módulo que contiene funciones puras para gestionar acciones relacionadas con sliders y porcentajes.
  """

  alias TicketSplitter.Tickets

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
end
