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
  """
  def calculate_min_participants(ticket_id) do
    real_participants_count = length(Tickets.get_ticket_participants(ticket_id))
    max(real_participants_count, 1)
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
