defmodule TicketSplitterWeb.TicketLive.ActingAsActions do
  @moduledoc """
  Módulo que contiene funciones puras para gestionar acciones relacionadas con "acting as".
  """

  alias TicketSplitter.Tickets

  @doc """
  Construye los assigns para establecer acting_as en un participante.
  """
  def build_acting_as_assigns(ticket_id, name, color) do
    acting_as_total = Tickets.calculate_participant_total_with_multiplier(ticket_id, name)
    acting_as_multiplier = Tickets.get_participant_multiplier(ticket_id, name)

    [
      acting_as_participant: name,
      acting_as_color: color,
      acting_as_total: acting_as_total,
      acting_as_multiplier: acting_as_multiplier
    ]
  end

  @doc """
  Construye los assigns para limpiar acting_as.
  """
  def build_clear_acting_as_assigns() do
    [
      acting_as_participant: nil,
      acting_as_color: nil,
      acting_as_total: Decimal.new("0"),
      acting_as_multiplier: 1
    ]
  end

  @doc """
  Verifica si un nombre de ghost ya existe.
  """
  def ghost_name_exists?(existing_participants, name) do
    Enum.any?(existing_participants, fn p -> p.name == name end)
  end

  @doc """
  Busca un participante por nombre.
  """
  def find_participant_by_name(existing_participants, name) do
    Enum.find(existing_participants, fn p -> p.name == name end)
  end
end
