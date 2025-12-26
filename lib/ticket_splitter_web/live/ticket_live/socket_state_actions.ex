defmodule TicketSplitterWeb.TicketLive.SocketStateActions do
  @moduledoc """
  Módulo que contiene funciones puras para calcular el estado del socket.
  """

  alias TicketSplitter.Tickets.TicketCalculator

  @doc """
  Calcula los assigns para my_total y my_multiplier.
  """
  def calculate_my_total_assigns(ticket_id, participant_name) do
    if participant_name do
      total =
        TicketSplitter.Tickets.calculate_participant_total_with_multiplier(
          ticket_id,
          participant_name
        )

      multiplier = TicketSplitter.Tickets.get_participant_multiplier(ticket_id, participant_name)

      [
        my_total: total,
        my_multiplier: multiplier
      ]
    else
      [
        my_total: Decimal.new("0"),
        my_multiplier: 1
      ]
    end
  end

  @doc """
  Calcula los assigns para los saldos principales (total_ticket, total_assigned, pending).
  """
  def calculate_main_saldos_assigns(products, total_participants) do
    total_ticket = TicketCalculator.calculate_ticket_total(products)
    total_assigned = TicketCalculator.calculate_total_assigned(products, total_participants)
    pending = Decimal.sub(total_ticket, total_assigned)

    [
      total_ticket_main: total_ticket,
      total_assigned_main: total_assigned,
      pending_main: pending
    ]
  end

  @doc """
  Obtiene el participante activo (acting_as o self).
  """
  def get_active_participant_name(socket) do
    socket.assigns.acting_as_participant || socket.assigns.participant_name
  end

  @doc """
  Obtiene el color del participante activo.
  """
  def get_active_participant_color(socket) do
    socket.assigns.acting_as_color || socket.assigns.participant_color
  end
end
