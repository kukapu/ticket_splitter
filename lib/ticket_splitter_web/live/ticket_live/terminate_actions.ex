defmodule TicketSplitterWeb.TicketLive.TerminateActions do
  @moduledoc """
  Módulo que contiene funciones para manejar la terminación de la conexión.
  """

  alias TicketSplitter.Tickets.TicketBroadcaster

  @doc """
  Ejecuta el desbloqueo de todos los sliders que tenía bloqueados el participante.
  """
  def unlock_participant_sliders(ticket_id, participant_name, locked_sliders) do
    if participant_name do
      Enum.each(locked_sliders, fn {group_id, locked_by} ->
        if locked_by == participant_name do
          TicketBroadcaster.broadcast_slider_unlock(ticket_id, group_id)
        end
      end)
    end

    :ok
  end
end
