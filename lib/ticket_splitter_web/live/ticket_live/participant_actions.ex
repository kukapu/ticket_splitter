defmodule TicketSplitterWeb.TicketLive.ParticipantActions do
  @moduledoc """
  Módulo consolidado que contiene todas las funciones para gestionar participantes.
  Incluye cálculos de conteo, actualizaciones, gestión de colores, assigns, etc.
  """

  alias TicketSplitter.Tickets
  alias TicketSplitter.Tickets.TicketBroadcaster
  alias TicketSplitter.Tickets.TicketColorManager
  alias TicketSplitterWeb.TicketLive.CalculationActions

  # ============================================================================
  # Funciones de cálculo de conteo (de ParticipantsCountActions)
  # ============================================================================

  @doc """
  Calcula el nuevo conteo al incrementar.
  """
  def calculate_increment(current_count) do
    current_count + 1
  end

  @doc """
  Calcula el nuevo conteo al decrementar (respetando el mínimo).
  """
  def calculate_decrement(current_count, min_count) do
    max(current_count - 1, min_count)
  end

  @doc """
  Parsea y valida un valor de conteo de participantes.
  """
  def parse_and_validate_value(value, _min_count) do
    case Integer.parse(value) do
      {num, _} when num > 0 ->
        {:ok, num}

      _ ->
        :error
    end
  end

  # ============================================================================
  # Funciones de actualización y broadcast (de ParticipantsUpdateActions)
  # ============================================================================

  @doc """
  Ejecuta la actualización del ticket y broadcast el update.
  """
  def execute_update_and_broadcast(ticket, new_count) do
    case TicketSplitter.Tickets.update_ticket(ticket, %{total_participants: new_count}) do
      {:ok, updated_ticket} ->
        TicketBroadcaster.broadcast_ticket_update(updated_ticket.id)
        {:ok, updated_ticket}

      {:error, _} ->
        :error
    end
  end

  @doc """
  Construye assigns para actualizar el resumen modal cuando está abierto.
  """
  def build_summary_modal_assigns(products, new_count, ticket_id, participants, updated_ticket) do
    {total_ticket, total_assigned, pending} =
      CalculationActions.calculate_summary_totals(products, new_count)

    participant_summaries =
      CalculationActions.calculate_participant_summaries(ticket_id, participants)

    [
      ticket: updated_ticket,
      participants_for_summary: participant_summaries,
      total_ticket_for_summary: total_ticket,
      total_assigned_for_summary: total_assigned,
      pending_for_summary: pending
    ]
  end

  @doc """
  Construye assigns básicos cuando no está abierto el modal de resumen.
  """
  def build_basic_assigns(ticket) do
    [ticket: ticket]
  end

  # ============================================================================
  # Funciones originales de ParticipantActions
  # ============================================================================

  @doc """
  Obtiene el color para un participante, reutilizando el existente si está disponible.
  """
  def get_participant_color(ticket_id, name, existing_participants) do
    existing_user_color = TicketColorManager.get_existing_user_color(ticket_id, name)

    if existing_user_color do
      existing_user_color
    else
      TicketColorManager.get_deterministic_color(name, existing_participants)
    end
  end

  @doc """
  Determina el nuevo conteo de participantes cuando se añade uno.
  No incrementa si el participante ya existe.
  """
  def calculate_new_participants_count(existing_participants, new_name) do
    current_count = length(existing_participants)

    if Enum.any?(existing_participants, fn p -> p.name == new_name end) do
      current_count
    else
      current_count + 1
    end
  end

  @doc """
  Determina si se debe actualizar el ticket con un nuevo número de participantes.
  Returns {:should_update, new_count} or :no_update
  """
  def should_update_participants_count?(current_total, new_count) do
    if new_count > current_total do
      {:should_update, new_count}
    else
      :no_update
    end
  end

  @doc """
  Prepara los participantes existentes con colores para el selector.
  """
  def prepare_participants_for_selector(ticket_id, existing_participants) do
    Enum.map(existing_participants, fn p ->
      %{
        name: p.name,
        color:
          TicketColorManager.get_existing_user_color(ticket_id, p.name) ||
            TicketColorManager.get_deterministic_color(p.name, existing_participants)
      }
    end)
  end

  @doc """
  Determina la acción a tomar cuando se cambia el nombre de un participante.
  Returns {:adopt, color}, {:update_db, color}, or {:change_only, color}
  """
  def determine_name_change_action(ticket_id, old_name, new_name, existing_participants) do
    has_assignments = Tickets.participant_has_assignments?(ticket_id, old_name)
    name_exists = Tickets.participant_name_exists?(ticket_id, new_name)

    color = get_participant_color(ticket_id, new_name, existing_participants)

    cond do
      has_assignments && name_exists ->
        {:error, :name_conflict}

      has_assignments && !name_exists ->
        {:update_db, color}

      !has_assignments && name_exists ->
        {:adopt, color}

      !has_assignments && !name_exists ->
        {:change_only, color}
    end
  end

  @doc """
  Construye los assigns para establecer el nombre del participante.
  """
  def build_participant_assigns(name, color, ticket) do
    [
      ticket: ticket,
      participant_name: name,
      participant_color: color
    ]
  end

  @doc """
  Verifica si un nombre de ghost ya existe entre los participantes.
  """
  def ghost_name_exists?(existing_participants, name) do
    Enum.any?(existing_participants, fn p -> p.name == name end)
  end

  @doc """
  Obtiene los datos de un participante existente por nombre.
  """
  def get_participant_by_name(existing_participants, name) do
    Enum.find(existing_participants, fn p -> p.name == name end)
  end
end
