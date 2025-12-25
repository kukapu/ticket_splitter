defmodule TicketSplitterWeb.TicketLive.Helpers do
  @moduledoc """
  Módulo que contiene funciones auxiliares puras para TicketLive.
  Incluye funciones para cálculos, formateo, validaciones y generación de metadatos SEO.
  """

  alias TicketSplitter.Tickets

  @doc """
  Formatea un Decimal a 2 decimales y lo convierte a string.
  """
  def format_decimal(decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string()
  end

  @doc """
  Agrupa las asignaciones por group_id para mostrarlas en la UI.
  """
  def group_assignments_by_group_id(assignments) do
    assignments
    |> Enum.group_by(fn pa -> pa.assignment_group_id end)
    |> Enum.map(fn {group_id, group_assignments} ->
      units = hd(group_assignments).units_assigned || Decimal.new("0")

      sorted_participants =
        group_assignments
        |> Enum.sort_by(& &1.participant_name)
        |> Enum.map(fn pa ->
          %{
            name: pa.participant_name,
            color: pa.assigned_color,
            percentage: pa.percentage
          }
        end)

      %{
        group_id: group_id,
        units_assigned: units,
        participants: sorted_participants
      }
    end)
  end

  @doc """
  Verifica si al quitar una asignación se requiere confirmación de "unshare".
  """
  def requires_unshare_confirmation?(products, product_id, participant_name, target_group_id) do
    product = Enum.find(products, fn p -> to_string(p.id) == to_string(product_id) end)

    if product do
      assignments =
        Enum.filter(product.participant_assignments, fn pa ->
          pa.participant_name == participant_name
        end)

      if target_group_id do
        target_assignment =
          Enum.find(assignments, fn pa -> pa.assignment_group_id == target_group_id end)

        if target_assignment do
          is_shared_group?(product, target_assignment.assignment_group_id)
        else
          false
        end
      else
        has_solo =
          Enum.any?(assignments, fn pa ->
            !is_shared_group?(product, pa.assignment_group_id)
          end)

        if has_solo do
          false
        else
          Enum.any?(assignments, fn pa ->
            is_shared_group?(product, pa.assignment_group_id)
          end)
        end
      end
    else
      false
    end
  end

  @doc """
  Verifica si un group_id pertenece a un grupo compartido (más de 1 participante).
  """
  def is_shared_group?(_product, nil), do: false

  def is_shared_group?(product, group_id) do
    count =
      Enum.count(product.participant_assignments, fn pa ->
        pa.assignment_group_id == group_id
      end)

    count > 1
  end

  @doc """
  Construye el título de la página para SEO (merchant_name + date).
  """
  def build_ticket_page_title(ticket) do
    title_parts = []

    title_parts =
      if ticket.merchant_name do
        [ticket.merchant_name | title_parts]
      else
        title_parts
      end

    title_parts =
      if ticket.date do
        date_str = Calendar.strftime(ticket.date, "%d/%m/%Y")
        ["#{date_str}" | title_parts]
      else
        title_parts
      end

    if title_parts != [] do
      ticket_title = Enum.join(title_parts, " - ")
      "Ticket Splitter - #{ticket_title}"
    else
      "Ticket Splitter"
    end
  end

  @doc """
  Construye la descripción de la página para SEO.
  """
  def build_ticket_page_description(ticket, total_ticket) do
    total_str = format_decimal(total_ticket)

    merchant_part =
      if ticket.merchant_name do
        "Ticket de #{ticket.merchant_name}"
      else
        "Ticket"
      end

    date_part =
      if ticket.date do
        date_str = Calendar.strftime(ticket.date, "%d de %B de %Y")
        " del #{date_str}"
      else
        ""
      end

    "Divide y gestiona #{merchant_part}#{date_part}. Total: €#{total_str}. Comparte los gastos entre tus amigos de forma fácil y justa con Ticket Splitter."
  end

  @doc """
  Obtiene todos los participantes de un ticket (desde DB).
  """
  def get_all_participants_from_db(ticket_id) do
    Tickets.get_ticket_participants(ticket_id)
  end
end
