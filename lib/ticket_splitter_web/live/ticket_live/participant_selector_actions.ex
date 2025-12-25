defmodule TicketSplitterWeb.TicketLive.ParticipantSelectorActions do
  @moduledoc """
  Módulo que contiene funciones para gestionar el selector de participantes.
  """

  @doc """
  Construye assigns para cerrar el selector de participantes.
  """
  def close_selector_assigns() do
    [
      show_participant_selector: false,
      existing_participants_for_selector: []
    ]
  end

  @doc """
  Construye assigns para abrir el modal de settings del usuario.
  """
  def open_user_settings_assigns() do
    # Esto se maneja con push_event, no con assigns
    []
  end
end
