defmodule TicketSplitterWeb.TicketLive.MultiplierActions do
  @moduledoc """
  Módulo que contiene funciones puras para gestionar acciones relacionadas con multiplicadores.
  """

  alias TicketSplitter.Tickets

  @doc """
  Obtiene el multiplicador actual del usuario activo (acting_as o self).
  """
  def get_current_multiplier(socket) do
    if socket.assigns.acting_as_participant do
      Tickets.get_participant_multiplier(
        socket.assigns.ticket.id,
        socket.assigns.acting_as_participant
      )
    else
      socket.assigns.my_multiplier
    end
  end

  @doc """
  Obtiene el participante objetivo (acting_as o self).
  """
  def get_target_participant(socket) do
    socket.assigns.acting_as_participant || socket.assigns.participant_name
  end

  @doc """
  Calcula el nuevo total de participantes basado en la diferencia de multiplicadores.
  """
  def calculate_new_total_participants(socket, multiplier_diff) do
    max(
      socket.assigns.ticket.total_participants + multiplier_diff,
      socket.assigns.min_participants
    )
  end

  @doc """
  Construye los assigns después de actualizar el multiplicador del usuario actual (self).
  """
  def build_self_assigns(new_multiplier) do
    [my_multiplier: new_multiplier]
  end

  @doc """
  Construye los assigns después de actualizar el multiplicador de acting_as.
  """
  def build_acting_as_assigns(ticket_id, acting_as_participant, new_multiplier) do
    acting_as_total = Tickets.calculate_participant_total_with_multiplier(ticket_id, acting_as_participant)

    [
      acting_as_total: acting_as_total,
      acting_as_multiplier: new_multiplier
    ]
  end
end
