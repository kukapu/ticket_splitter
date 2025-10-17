defmodule TicketSplitterWeb.TicketLive do
  use TicketSplitterWeb, :live_view

  alias TicketSplitter.Tickets

  @colors [
    "#EF4444", "#F59E0B", "#10B981", "#3B82F6", "#8B5CF6",
    "#EC4899", "#14B8A6", "#F97316", "#06B6D4", "#84CC16"
  ]

  @impl true
  def mount(%{"id" => ticket_id}, _session, socket) do
    ticket = Tickets.get_ticket_with_products!(ticket_id)

    socket =
      socket
      |> assign(:ticket, ticket)
      |> assign(:products, ticket.products)
      |> assign(:participant_name, nil)
      |> assign(:participant_color, nil)
      |> assign(:show_name_modal, false)
      |> assign(:show_summary_modal, false)
      |> assign(:editing_percentages_product_id, nil)
      |> assign(:my_total, Decimal.new("0"))

    {:ok, socket}
  end

  @impl true
  def handle_event("set_participant_name", %{"name" => name}, socket) do
    # Asignar color único al participante
    existing_participants = Tickets.get_ticket_participants(socket.assigns.ticket.id)
    used_colors = Enum.map(existing_participants, & &1.color)
    available_colors = @colors -- used_colors
    color = Enum.random(available_colors || @colors)

    socket =
      socket
      |> assign(:participant_name, name)
      |> assign(:participant_color, color)
      |> assign(:show_name_modal, false)
      |> push_event("save_participant_name", %{name: name})
      |> calculate_my_total()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_product", %{"product_id" => product_id}, socket) do
    participant_name = socket.assigns.participant_name
    color = socket.assigns.participant_color

    unless participant_name do
      {:noreply, assign(socket, :show_name_modal, true)}
    else
      case Tickets.toggle_participant_assignment(product_id, participant_name, color) do
        {:ok, _} ->
          # Recargar ticket con productos actualizados
          ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

          socket =
            socket
            |> assign(:ticket, ticket)
            |> assign(:products, ticket.products)
            |> calculate_my_total()

          {:noreply, socket}

        {:error, _} ->
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("toggle_common", %{"product_id" => product_id}, socket) do
    product = Tickets.get_product!(product_id)

    case Tickets.toggle_product_common(product) do
      {:ok, _} ->
        # Recargar ticket
        ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

        socket =
          socket
          |> assign(:ticket, ticket)
          |> assign(:products, ticket.products)
          |> calculate_my_total()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_total_participants", %{"value" => value}, socket) do
    case Integer.parse(value) do
      {num, _} when num > 0 ->
        case Tickets.update_ticket(socket.assigns.ticket, %{total_participants: num}) do
          {:ok, ticket} ->
            socket =
              socket
              |> assign(:ticket, ticket)
              |> calculate_my_total()

            {:noreply, socket}

          {:error, _} ->
            {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_summary", _params, socket) do
    {:noreply, assign(socket, :show_summary_modal, true)}
  end

  @impl true
  def handle_event("close_summary", _params, socket) do
    {:noreply, assign(socket, :show_summary_modal, false)}
  end

  @impl true
  def handle_event("open_edit_percentages", %{"product_id" => product_id}, socket) do
    {:noreply, assign(socket, :editing_percentages_product_id, product_id)}
  end

  @impl true
  def handle_event("close_edit_percentages", _params, socket) do
    {:noreply, assign(socket, :editing_percentages_product_id, nil)}
  end

  @impl true
  def handle_event("save_percentages", %{"assignments" => assignments_map}, socket) do
    updates =
      Enum.map(assignments_map, fn {assignment_id, percentage_str} ->
        {percentage, _} = Float.parse(percentage_str)
        {assignment_id, Decimal.new(to_string(percentage))}
      end)

    Tickets.update_custom_percentages(updates)

    # Recargar ticket
    ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

    socket =
      socket
      |> assign(:ticket, ticket)
      |> assign(:products, ticket.products)
      |> assign(:editing_percentages_product_id, nil)
      |> calculate_my_total()

    {:noreply, socket}
  end

  @impl true
  def handle_event("participant_name_from_storage", %{"name" => name}, socket) do
    if name && name != "" do
      # El usuario ya tiene nombre guardado
      handle_event("set_participant_name", %{"name" => name}, socket)
    else
      # Mostrar modal para pedir nombre
      {:noreply, assign(socket, :show_name_modal, true)}
    end
  end

  defp calculate_my_total(socket) do
    participant_name = socket.assigns.participant_name

    total =
      if participant_name do
        Tickets.calculate_participant_total(socket.assigns.ticket.id, participant_name)
      else
        Decimal.new("0")
      end

    assign(socket, :my_total, total)
  end

  defp product_assigned_to_me?(product, participant_name) do
    Enum.any?(product.participant_assignments, fn pa ->
      pa.participant_name == participant_name
    end)
  end

  defp get_product_participants(product) do
    Enum.map(product.participant_assignments, fn pa ->
      %{
        name: pa.participant_name,
        color: pa.assigned_color,
        percentage: pa.percentage
      }
    end)
  end

  defp format_decimal(decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string()
  end

  defp get_all_participants(socket) do
    Tickets.get_ticket_participants(socket.assigns.ticket.id)
  end

  defp calculate_participant_summary(ticket_id, participant) do
    total = Tickets.calculate_participant_total(ticket_id, participant.name)
    %{name: participant.name, color: participant.color, total: total}
  end

  defp calculate_total_assigned(products) do
    Enum.reduce(products, Decimal.new("0"), fn product, acc ->
      if product.is_common do
        Decimal.add(acc, product.total_price)
      else
        product_total =
          Enum.reduce(product.participant_assignments, Decimal.new("0"), fn pa, prod_acc ->
            share =
              Decimal.mult(
                product.total_price,
                Decimal.div(pa.percentage, Decimal.new("100"))
              )

            Decimal.add(prod_acc, share)
          end)

        Decimal.add(acc, product_total)
      end
    end)
  end

  defp calculate_ticket_total(products) do
    Enum.reduce(products, Decimal.new("0"), fn product, acc ->
      Decimal.add(acc, product.total_price)
    end)
  end
end
