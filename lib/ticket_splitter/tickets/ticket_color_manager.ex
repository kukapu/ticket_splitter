defmodule TicketSplitter.Tickets.TicketColorManager do
  @moduledoc """
  Manages participant color assignment and retrieval.
  Extracted from TicketLive for better testability.
  """

  @colors [
    "#FF3D00",
    "#FF9100",
    "#FFD600",
    "#FF6D00",
    "#F50057",
    "#FF4081",
    "#E040FB",
    "#76FF03",
    "#00E676",
    "#00C853",
    "#2979FF",
    "#3D5AFE",
    "#00B0FF",
    "#90A4AE",
    "#A1887F"
  ]

  @doc """
  Gets existing user color from their assignments.
  Returns nil if the user has no assignments.
  """
  def get_existing_user_color(ticket_id, participant_name) do
    # Buscar todas las asignaciones del usuario en este ticket
    assignments =
      TicketSplitter.Tickets.get_participant_assignments_by_ticket(ticket_id, participant_name)

    # Si tiene asignaciones, usar el color de la primera
    case assignments do
      [first_assignment | _] -> first_assignment.assigned_color
      [] -> nil
    end
  end

  @doc """
  Generates deterministic color based on participant name.
  Uses a hash of the name to select from the color palette,
  avoiding colors already in use by other participants.
  """
  def get_deterministic_color(name, existing_participants) do
    # Obtener colores ya usados
    used_colors = Enum.map(existing_participants, & &1.color)

    # Generar hash del nombre para obtener siempre el mismo índice
    name_hash = :erlang.phash2(name)
    color_index = rem(name_hash, length(@colors))

    # Encontrar un color disponible empezando desde el índice determinista
    color = get_available_color_from_index(color_index, used_colors)

    color
  end

  @doc """
  Finds available color from starting index.
  Searches through the color palette starting at start_index,
  skipping colors that are already in use.
  """
  def get_available_color_from_index(start_index, used_colors) do
    # Probar colores desde el índice inicial en adelante
    {color, _} =
      Stream.iterate(start_index, &rem(&1 + 1, length(@colors)))
      |> Stream.map(&Enum.at(@colors, &1))
      |> Stream.reject(&(&1 in used_colors))
      |> Enum.take(1)
      |> List.pop_at(0) || {Enum.at(@colors, start_index), start_index}

    color
  end

  @doc """
  Returns the full color palette.
  """
  def colors, do: @colors
end
