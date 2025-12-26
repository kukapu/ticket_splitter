defmodule TicketSplitterWeb.TicketLive.MountActions do
  @moduledoc """
  Módulo que contiene funciones para la inicialización en mount.
  """

  alias TicketSplitter.Tickets
  alias TicketSplitter.Tickets.TicketCalculator
  alias TicketSplitterWeb.SEO
  alias TicketSplitterWeb.TicketLive.Helpers

  @doc """
  Calcula los saldos iniciales del ticket.
  """
  def calculate_initial_saldos(products, total_participants) do
    total_ticket = TicketCalculator.calculate_ticket_total(products)
    total_assigned = TicketCalculator.calculate_total_assigned(products, total_participants)
    pending = Decimal.sub(total_ticket, total_assigned)

    {total_ticket, total_assigned, pending}
  end

  @doc """
  Calcula el conteo mínimo de participantes permitido.
  Es el máximo entre:
  - Número de participantes activos
  - Suma de multiplicadores de todos los participantes activos
  """
  def calculate_min_participants(ticket_id) do
    active_participants = Tickets.get_ticket_participants(ticket_id)
    configs = Tickets.list_participant_configs(ticket_id)

    # Suma de multiplicadores de participantes activos (default 1 si no tienen config)
    sum_multipliers =
      Enum.reduce(active_participants, 0, fn participant, acc ->
        multiplier =
          Enum.find_value(configs, 1, fn config ->
            if config.participant_name == participant.name, do: config.multiplier, else: nil
          end)

        acc + multiplier
      end)

    # El mínimo es la suma de multiplicadores, o 1 si no hay participantes
    max(sum_multipliers, 1)
  end

  @doc """
  Construye los assigns de metadatos de página (SEO).
  """
  def build_page_metadata_assigns(ticket, total_ticket) do
    page_title = Helpers.build_ticket_page_title(ticket)
    page_description = Helpers.build_ticket_page_description(ticket, total_ticket)
    page_url = SEO.absolute_url("/tickets/#{ticket.id}")

    [
      page_title: page_title,
      page_description: page_description,
      page_url: page_url
    ]
  end

  @doc """
  Construye todos los assigns iniciales del socket.
  """
  def build_initial_socket_assigns(
        ticket,
        total_ticket,
        total_assigned,
        pending,
        min_participants,
        page_metadata
      ) do
    [
      ticket: ticket,
      products: ticket.products,
      participant_name: nil,
      participant_color: nil,
      show_summary_modal: false,
      show_share_modal: false,
      show_image_modal: false,
      show_participant_selector: false,
      existing_participants_for_selector: [],
      show_instructions: false,
      show_share_confirmation: false,
      show_unshare_confirmation: false,
      pending_share_action: nil,
      editing_percentages_product_id: nil,
      my_total: Decimal.new("0"),
      my_multiplier: 1,
      acting_as_participant: nil,
      acting_as_color: nil,
      acting_as_total: Decimal.new("0"),
      acting_as_multiplier: 1,
      summary_tab: "summary",
      total_ticket_main: total_ticket,
      total_assigned_main: total_assigned,
      pending_main: pending,
      participants_for_summary: [],
      min_participants: min_participants,
      locked_sliders: %{}
    ]
    |> Keyword.merge(page_metadata)
  end

  @doc """
  Construye el mapa de ticket para guardar en historial.
  """
  def build_ticket_history_map(ticket) do
    %{
      id: ticket.id,
      merchant_name: ticket.merchant_name,
      date: ticket.date
    }
  end
end
