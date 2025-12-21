defmodule TicketSplitterWeb.TicketLive do
  use TicketSplitterWeb, :live_view

  alias TicketSplitter.Tickets

  # @colors [
  #   # Paleta moderna inspirada en violeta/índigo - 15 colores profesionales
  #   # Violeta primario (Sustituido por Purple-700 para evitar conflicto con Primary #7B61FF)
  #   "#9333EA",
  #   # Verde esmeralda (como botón compartir)
  #   "#10B981",
  #   # Azul brillante (complementario del cyan)
  #   "#3B82F6",
  #   # Naranja vibrante (Sustituido por Orange-600 para evitar conflicto con Secondary #FFB84C)
  #   "#EA580C",
  #   # Rosa moderno (elegante y sofisticado)
  #   "#EC4899",
  #   # Verde teal (Sustituido por Teal-700 para evitar conflicto con Auxiliary #14B8A6)
  #   "#0D9488",
  #   # Índigo claro (Sustituido por Indigo-600 para evitar conflicto con Primary)
  #   "#4F46E5",
  #   # Ámbar (Sustituido por Amber-600 para evitar conflicto con Secondary)
  #   "#D97706",
  #   # Cyan profundo (moderno tecnológico)
  #   "#06B6D4",
  #   # Lima verde (vital y fresco)
  #   "#84CC16",
  #   # Índigo-violeta intermedio
  #   "#6366F1",
  #   # Café elegante (sofisticado)
  #   "#8B4513",
  #   # Rojo intenso (emergencia pero moderno)
  #   "#DC2626",
  #   # Verde bosque profundo
  #   "#059669",
  #   # Terracota cálido (natural y elegante)
  #   "#7C2D12"
  # ]

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

  @impl true
  def mount(%{"id" => ticket_id}, _session, socket) do
    # Suscribirse al tópico del ticket para recibir actualizaciones en tiempo real
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TicketSplitter.PubSub, "ticket:#{ticket_id}")
    end

    alias TicketSplitterWeb.SEO

    ticket = Tickets.get_ticket_with_products!(ticket_id)

    # Calcular saldos iniciales
    total_ticket = calculate_ticket_total(ticket.products)
    total_assigned = calculate_total_assigned(ticket.products, ticket.total_participants)
    pending = Decimal.sub(total_ticket, total_assigned)

    # Calcular el número real de participantes con asignaciones
    real_participants_count = length(Tickets.get_ticket_participants(ticket_id))
    min_participants = max(real_participants_count, 1)

    # Generar título y descripción dinámicos para SEO
    page_title = build_ticket_page_title(ticket)
    page_description = build_ticket_page_description(ticket, total_ticket)
    page_url = SEO.absolute_url("/tickets/#{ticket_id}")

    socket =
      socket
      |> assign(:ticket, ticket)
      |> assign(:products, ticket.products)
      |> assign(:participant_name, nil)
      |> assign(:participant_color, nil)
      |> assign(:show_name_modal, false)
      |> assign(:show_summary_modal, false)
      |> assign(:show_share_modal, false)
      |> assign(:show_instructions, false)
      |> assign(:show_share_confirmation, false)
      |> assign(:show_unshare_confirmation, false)
      |> assign(:pending_share_action, nil)
      |> assign(:editing_percentages_product_id, nil)
      |> assign(:my_total, Decimal.new("0"))
      |> assign(:total_ticket_main, total_ticket)
      |> assign(:total_assigned_main, total_assigned)
      |> assign(:pending_main, pending)
      |> assign(:min_participants, min_participants)
      |> assign(:locked_sliders, %{})
      |> assign(:page_title, page_title)
      |> assign(:page_description, page_description)
      |> assign(:page_url, page_url)

    {:ok, socket}
  end

  @impl true
  def handle_event("set_participant_name", %{"name" => name}, socket) do
    # Normalize name to lowercase for case-insensitive comparison
    name = String.downcase(String.trim(name))

    # Asignar color consistente basado en el nombre del usuario
    existing_participants = Tickets.get_ticket_participants(socket.assigns.ticket.id)

    # Primero, verificar si el usuario ya tiene asignaciones previas con un color
    existing_user_color = get_existing_user_color(socket.assigns.ticket.id, name)

    color =
      if existing_user_color do
        # Usar el color existente del usuario
        existing_user_color
      else
        # Generar color determinista basado en el nombre
        get_deterministic_color(name, existing_participants)
      end

    # Actualizar automáticamente el número de participantes si es necesario
    current_participants_count = length(existing_participants)

    # Si el participante ya existe, no aumentar el conteo
    final_participants_count =
      if Enum.any?(existing_participants, fn p -> p.name == name end) do
        current_participants_count
      else
        current_participants_count + 1
      end

    # Actualizar el ticket si el número de participantes es mayor que el configurado
    ticket =
      if final_participants_count > socket.assigns.ticket.total_participants do
        {:ok, updated_ticket} =
          Tickets.update_ticket(socket.assigns.ticket, %{
            total_participants: final_participants_count
          })

        # Broadcast a todos los usuarios sobre el cambio
        broadcast_ticket_update(socket.assigns.ticket.id)

        updated_ticket
      else
        socket.assigns.ticket
      end

    socket =
      socket
      |> assign(:ticket, ticket)
      |> assign(:participant_name, name)
      |> assign(:participant_color, color)
      |> assign(:show_name_modal, false)
      |> push_event("save_participant_name", %{name: name})
      |> push_event("save_ticket_to_history", %{
        ticket: %{
          id: ticket.id,
          merchant_name: ticket.merchant_name,
          date: ticket.date
        }
      })
      |> calculate_my_total()
      |> update_main_saldos()

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "toggle_product",
        %{"product_id" => _product_id, "action" => action} = params,
        socket
      ) do
    participant_name = socket.assigns.participant_name
    _color = socket.assigns.participant_color

    unless participant_name do
      {:noreply, assign(socket, :show_name_modal, true)}
    else
      cond do
        action == "join_group" ->
          {:noreply,
           socket
           |> assign(:show_share_confirmation, true)
           |> assign(:pending_share_action, params)}

        action == "remove_unit" ->
          target_group_id = Map.get(params, "group_id")

          if requires_unshare_confirmation?(
               socket.assigns.products,
               params["product_id"],
               participant_name,
               target_group_id
             ) do
            {:noreply,
             socket
             |> assign(:show_unshare_confirmation, true)
             |> assign(:pending_share_action, params)}
          else
            execute_toggle_action(action, params, socket)
          end

        true ->
          execute_toggle_action(action, params, socket)
      end
    end
  end

  def handle_event("confirm_unshare", _params, socket) do
    params = socket.assigns.pending_share_action

    socket =
      socket
      |> assign(:show_unshare_confirmation, false)
      |> assign(:pending_share_action, nil)

    execute_toggle_action("remove_unit", params, socket)
  end

  def handle_event("cancel_unshare", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_unshare_confirmation, false)
     |> assign(:pending_share_action, nil)}
  end

  def handle_event("confirm_share", _params, socket) do
    params = socket.assigns.pending_share_action

    socket =
      socket
      |> assign(:show_share_confirmation, false)
      |> assign(:pending_share_action, nil)

    execute_toggle_action("join_group", params, socket)
  end

  def handle_event("cancel_share", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_share_confirmation, false)
     |> assign(:pending_share_action, nil)}
  end

  @impl true
  def handle_event("toggle_common", %{"product_id" => product_id}, socket) do
    product = Tickets.get_product!(product_id)

    case Tickets.toggle_product_common(product) do
      {:ok, _} ->
        # Broadcast a todos los usuarios conectados
        broadcast_ticket_update(socket.assigns.ticket.id)

        # Recargar ticket
        ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

        socket =
          socket
          |> assign(:ticket, ticket)
          |> assign(:products, ticket.products)
          |> calculate_my_total()
          |> update_main_saldos()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("make_common", %{"product_id" => product_id}, socket) do
    case Tickets.add_common_units(product_id, 1) do
      {:ok, _} ->
        broadcast_ticket_update(socket.assigns.ticket.id)
        ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

        socket =
          socket
          |> assign(:ticket, ticket)
          |> assign(:products, ticket.products)
          |> calculate_my_total()
          |> update_main_saldos()

        {:noreply, socket}

      {:error, :not_enough_units} ->
        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_from_common", %{"product_id" => product_id}, socket) do
    product = Tickets.get_product!(product_id)

    case Tickets.make_product_not_common(product) do
      {:ok, _} ->
        # Broadcast a todos los usuarios conectados
        broadcast_ticket_update(socket.assigns.ticket.id)

        # Recargar ticket
        ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

        socket =
          socket
          |> assign(:ticket, ticket)
          |> assign(:products, ticket.products)
          |> calculate_my_total()
          |> update_main_saldos()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_common_unit", %{"product_id" => product_id}, socket) do
    IO.puts("🔵 ADD_COMMON_UNIT event received for product_id: #{product_id}")

    case Tickets.add_common_units(product_id, 1) do
      {:ok, _} ->
        broadcast_ticket_update(socket.assigns.ticket.id)
        ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

        socket =
          socket
          |> assign(:ticket, ticket)
          |> assign(:products, ticket.products)
          |> calculate_my_total()
          |> update_main_saldos()

        {:noreply, socket}

      {:error, :not_enough_units} ->
        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_common_unit", %{"product_id" => product_id}, socket) do
    IO.puts("🔴 REMOVE_COMMON_UNIT event received for product_id: #{product_id}")

    case Tickets.remove_common_units(product_id, 1) do
      {:ok, _} ->
        broadcast_ticket_update(socket.assigns.ticket.id)
        ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

        socket =
          socket
          |> assign(:ticket, ticket)
          |> assign(:products, ticket.products)
          |> calculate_my_total()
          |> update_main_saldos()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("increment_participants", _params, socket) do
    new_count = socket.assigns.ticket.total_participants + 1
    update_participants_count(new_count, socket)
  end

  @impl true
  def handle_event("decrement_participants", _params, socket) do
    new_count = max(socket.assigns.ticket.total_participants - 1, socket.assigns.min_participants)
    update_participants_count(new_count, socket)
  end

  @impl true
  def handle_event("update_total_participants", %{"value" => value}, socket) do
    case Integer.parse(value) do
      {num, _} when num > 0 ->
        # El browser ya previene valores menores a min_participants gracias al atributo min del input
        # Simplemente actualizamos si el valor es válido
        update_participants_count(num, socket)

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_summary", _params, socket) do
    # Pre-calcular todos los datos que necesita el modal
    participants = get_all_participants(socket.assigns)

    participant_summaries =
      Enum.map(participants, fn participant ->
        calculate_participant_summary(socket.assigns.ticket.id, participant)
      end)

    total_ticket = calculate_ticket_total(socket.assigns.products)

    total_assigned =
      calculate_total_assigned(socket.assigns.products, socket.assigns.ticket.total_participants)

    pending = Decimal.sub(total_ticket, total_assigned)

    # Calculate "Rest of participants" if applicable
    active_count = length(participants)
    total_participants = socket.assigns.ticket.total_participants

    participant_summaries =
      if total_participants > active_count do
        rest_count = total_participants - active_count

        # Calculate total common cost
        total_common = calculate_total_common(socket.assigns.products)

        # Calculate rest share of common: (Total Common / Total Participants) * Rest Count
        rest_common_share =
          if total_participants > 0 do
            share_per_person = Decimal.div(total_common, Decimal.new(total_participants))
            Decimal.mult(share_per_person, Decimal.new(rest_count))
          else
            Decimal.new("0")
          end

        # Rest group pays for their common share + ALL pending (unassigned)
        rest_total = Decimal.add(rest_common_share, pending)

        # Calculate individual share for display
        rest_individual_total =
          if rest_count > 0 do
            Decimal.div(rest_total, Decimal.new(rest_count))
          else
            Decimal.new("0")
          end

        rest_summary = %{
          name: "#{gettext("Rest of participants")} (#{rest_count}x)",
          # Slate-400
          color: "#94a3b8",
          total: rest_individual_total,
          is_rest: true
        }

        # Return updated list and updated totals (Pending is fully absorbed by Rest)
        # Note: We still add the FULL rest_total to total_assigned calculation to balance the ticket 0 sum
        {participant_summaries ++ [rest_summary], Decimal.add(total_assigned, pending),
         Decimal.new("0")}
      else
        {participant_summaries, total_assigned, pending}
      end

    {final_summaries, final_total_assigned, final_pending} = participant_summaries

    {:noreply,
     socket
     |> assign(:show_summary_modal, true)
     |> assign(:participants_for_summary, final_summaries)
     |> assign(:total_ticket_for_summary, total_ticket)
     |> assign(:total_assigned_for_summary, final_total_assigned)
     |> assign(:pending_for_summary, final_pending)}
  end

  @impl true
  def handle_event("close_summary", _params, socket) do
    {:noreply, assign(socket, :show_summary_modal, false)}
  end

  @impl true
  def handle_event("toggle_instructions", _params, socket) do
    {:noreply, assign(socket, :show_instructions, !socket.assigns.show_instructions)}
  end

  @impl true
  def handle_event("open_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, true)}
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, false)}
  end

  @impl true
  def handle_event(
        "adjust_split_percentage",
        %{
          "group_id" => group_id,
          "participant1_percentage" => p1_percentage,
          "participant2_percentage" => p2_percentage
        },
        socket
      ) do
    # Verify that this user has the lock for this slider
    participant_name = socket.assigns.participant_name
    locked_by = Map.get(socket.assigns.locked_sliders, group_id)

    if locked_by == participant_name do
      # Update participant percentages in the database
      case Tickets.update_split_percentages(group_id, p1_percentage, p2_percentage) do
        :ok ->
          # Broadcast update to all users
          broadcast_ticket_update(socket.assigns.ticket.id)

          # Reload ticket data
          ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

          socket =
            socket
            |> assign(:ticket, ticket)
            |> assign(:products, ticket.products)
            |> calculate_my_total()
            |> update_main_saldos()

          {:noreply, socket}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      # User doesn't have the lock, ignore the request
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lock_slider", %{"group_id" => group_id}, socket) do
    participant_name = socket.assigns.participant_name

    # Check if slider is already locked
    case Map.get(socket.assigns.locked_sliders, group_id) do
      nil ->
        # Not locked, acquire lock
        locked_sliders = Map.put(socket.assigns.locked_sliders, group_id, participant_name)

        # Broadcast lock to all users
        broadcast_slider_lock(socket.assigns.ticket.id, group_id, participant_name)

        {:noreply, assign(socket, :locked_sliders, locked_sliders)}

      ^participant_name ->
        # Already locked by this user, nothing to do
        {:noreply, socket}

      _other_user ->
        # Locked by another user, reject
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unlock_slider", %{"group_id" => group_id}, socket) do
    participant_name = socket.assigns.participant_name
    locked_by = Map.get(socket.assigns.locked_sliders, group_id)

    # Only unlock if this user has the lock
    if locked_by == participant_name do
      locked_sliders = Map.delete(socket.assigns.locked_sliders, group_id)

      # Broadcast unlock to all users
      broadcast_slider_unlock(socket.assigns.ticket.id, group_id)

      {:noreply, assign(socket, :locked_sliders, locked_sliders)}
    else
      {:noreply, socket}
    end
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

    # Broadcast a todos los usuarios conectados
    broadcast_ticket_update(socket.assigns.ticket.id)

    # Recargar ticket
    ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

    socket =
      socket
      |> assign(:ticket, ticket)
      |> assign(:products, ticket.products)
      |> assign(:editing_percentages_product_id, nil)
      |> calculate_my_total()
      |> update_main_saldos()

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

  defp execute_toggle_action(action, params, socket) do
    participant_name = socket.assigns.participant_name
    color = socket.assigns.participant_color
    product_id = Map.get(params, "product_id")

    result =
      case action do
        "add_unit" ->
          # Añadir 1 unidad desde el pool
          Tickets.add_participant_unit(product_id, participant_name, color)

        "remove_unit" ->
          # Quitar 1 unidad (devolver al pool)
          group_id = Map.get(params, "group_id")
          Tickets.remove_participant_unit(product_id, participant_name, group_id)

        "join_group" ->
          # Unirse a un grupo existente (compartir)
          group_id = Map.get(params, "group_id")
          Tickets.join_assignment_group(group_id, participant_name, color)

        _ ->
          {:error, :invalid_action}
      end

    case result do
      {:ok, _} ->
        # Broadcast a todos los usuarios conectados
        broadcast_ticket_update(socket.assigns.ticket.id)

        # Recargar ticket con productos actualizados
        ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

        # Recalcular min_participants
        real_participants_count =
          length(Tickets.get_ticket_participants(socket.assigns.ticket.id))

        min_participants = max(real_participants_count, 1)

        socket =
          socket
          |> assign(:ticket, ticket)
          |> assign(:products, ticket.products)
          |> assign(:min_participants, min_participants)
          |> calculate_my_total()
          |> update_main_saldos()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp update_participants_count(new_count, socket) do
    case Tickets.update_ticket(socket.assigns.ticket, %{total_participants: new_count}) do
      {:ok, ticket} ->
        # Broadcast a todos los usuarios conectados
        broadcast_ticket_update(socket.assigns.ticket.id)

        # Recalcular datos del resumen si el modal está abierto
        socket =
          if socket.assigns.show_summary_modal do
            participants = get_all_participants(socket.assigns)

            participant_summaries =
              Enum.map(participants, fn participant ->
                calculate_participant_summary(socket.assigns.ticket.id, participant)
              end)

            total_ticket = calculate_ticket_total(socket.assigns.products)
            total_assigned = calculate_total_assigned(socket.assigns.products, new_count)
            pending = Decimal.sub(total_ticket, total_assigned)

            socket
            |> assign(:ticket, ticket)
            |> assign(:participants_for_summary, participant_summaries)
            |> assign(:total_ticket_for_summary, total_ticket)
            |> assign(:total_assigned_for_summary, total_assigned)
            |> assign(:pending_for_summary, pending)
            |> calculate_my_total()
            |> update_main_saldos()
          else
            socket
            |> assign(:ticket, ticket)
            |> calculate_my_total()
            |> update_main_saldos()
          end

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:ticket_updated, ticket_id}, socket) do
    # Recibir actualización del ticket desde otro usuario
    if ticket_id == socket.assigns.ticket.id do
      ticket = Tickets.get_ticket_with_products!(ticket_id)

      # Recalcular min_participants
      real_participants_count = length(Tickets.get_ticket_participants(ticket_id))
      min_participants = max(real_participants_count, 1)

      # Recalcular datos del resumen si el modal está abierto
      socket =
        if socket.assigns.show_summary_modal do
          participants = get_all_participants(socket.assigns)

          participant_summaries =
            Enum.map(participants, fn participant ->
              calculate_participant_summary(socket.assigns.ticket.id, participant)
            end)

          total_ticket = calculate_ticket_total(ticket.products)
          total_assigned = calculate_total_assigned(ticket.products, ticket.total_participants)
          pending = Decimal.sub(total_ticket, total_assigned)

          socket
          |> assign(:ticket, ticket)
          |> assign(:products, ticket.products)
          |> assign(:min_participants, min_participants)
          |> assign(:participants_for_summary, participant_summaries)
          |> assign(:total_ticket_for_summary, total_ticket)
          |> assign(:total_assigned_for_summary, total_assigned)
          |> assign(:pending_for_summary, pending)
          |> calculate_my_total()
          |> update_main_saldos()
        else
          socket
          |> assign(:ticket, ticket)
          |> assign(:products, ticket.products)
          |> assign(:min_participants, min_participants)
          |> calculate_my_total()
          |> update_main_saldos()
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:slider_locked, group_id, locked_by}, socket) do
    # Another user has locked a slider
    locked_sliders = Map.put(socket.assigns.locked_sliders, group_id, locked_by)

    socket =
      socket
      |> assign(:locked_sliders, locked_sliders)
      |> push_event("slider_locked", %{group_id: group_id, locked_by: locked_by})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:slider_unlocked, group_id}, socket) do
    # Another user has unlocked a slider
    locked_sliders = Map.delete(socket.assigns.locked_sliders, group_id)

    socket =
      socket
      |> assign(:locked_sliders, locked_sliders)
      |> push_event("slider_unlocked", %{group_id: group_id})

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    # When a user disconnects, unlock all sliders they had locked
    participant_name = socket.assigns.participant_name

    if participant_name do
      Enum.each(socket.assigns.locked_sliders, fn {group_id, locked_by} ->
        if locked_by == participant_name do
          broadcast_slider_unlock(socket.assigns.ticket.id, group_id)
        end
      end)
    end

    :ok
  end

  # Private functions

  defp broadcast_ticket_update(ticket_id) do
    Phoenix.PubSub.broadcast(
      TicketSplitter.PubSub,
      "ticket:#{ticket_id}",
      {:ticket_updated, ticket_id}
    )
  end

  defp broadcast_slider_lock(ticket_id, group_id, locked_by) do
    Phoenix.PubSub.broadcast(
      TicketSplitter.PubSub,
      "ticket:#{ticket_id}",
      {:slider_locked, group_id, locked_by}
    )
  end

  defp broadcast_slider_unlock(ticket_id, group_id) do
    Phoenix.PubSub.broadcast(
      TicketSplitter.PubSub,
      "ticket:#{ticket_id}",
      {:slider_unlocked, group_id}
    )
  end

  defp group_assignments_by_group_id(assignments) do
    assignments
    |> Enum.group_by(fn pa -> pa.assignment_group_id end)
    |> Enum.map(fn {group_id, group_assignments} ->
      # All assignments in a group share the same units
      units = hd(group_assignments).units_assigned || Decimal.new("0")

      # Sort participants alphabetically (same order as in database)
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

  defp update_main_saldos(socket) do
    total_ticket = calculate_ticket_total(socket.assigns.products)

    total_assigned =
      calculate_total_assigned(socket.assigns.products, socket.assigns.ticket.total_participants)

    pending = Decimal.sub(total_ticket, total_assigned)

    socket
    |> assign(:total_ticket_main, total_ticket)
    |> assign(:total_assigned_main, total_assigned)
    |> assign(:pending_main, pending)
  end

  defp format_decimal(decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string()
  end

  defp get_all_participants(%{assigns: assigns}) do
    Tickets.get_ticket_participants(assigns.ticket.id)
  end

  defp get_all_participants(assigns) when is_map(assigns) do
    Tickets.get_ticket_participants(assigns.ticket.id)
  end

  defp calculate_participant_summary(ticket_id, participant) do
    total = Tickets.calculate_participant_total(ticket_id, participant.name)
    %{name: participant.name, color: participant.color, total: total}
  end

  defp calculate_total_assigned(products, _total_participants) do
    Enum.reduce(products, Decimal.new("0"), fn product, acc ->
      # Legacy is_common support
      legacy_common_cost =
        if product.is_common do
          product.total_price
        else
          Decimal.new("0")
        end

      # New common_units support
      common_units = product.common_units || Decimal.new("0")

      common_units_cost =
        if Decimal.compare(common_units, Decimal.new("0")) == :gt do
          unit_cost = Decimal.div(product.total_price, Decimal.new(product.units))
          Decimal.mult(unit_cost, common_units)
        else
          Decimal.new("0")
        end

      # For non-common products, calculate based on assigned units
      # Get all unique assignment groups for this product
      assigned_groups_cost =
        product.participant_assignments
        |> Enum.group_by(fn pa -> pa.assignment_group_id end)
        |> Enum.map(fn {_group_id, assignments} ->
          # All assignments in a group share the same units
          units = hd(assignments).units_assigned || Decimal.new("0")
          # Calculate cost for these units
          unit_cost = Decimal.div(product.total_price, Decimal.new(product.units))
          Decimal.mult(unit_cost, units)
        end)
        |> Enum.reduce(Decimal.new("0"), fn group_cost, total ->
          Decimal.add(total, group_cost)
        end)

      # Sum all costs
      product_total =
        Decimal.add(legacy_common_cost, Decimal.add(common_units_cost, assigned_groups_cost))

      Decimal.add(acc, product_total)
    end)
  end

  defp calculate_ticket_total(products) do
    Enum.reduce(products, Decimal.new("0"), fn product, acc ->
      Decimal.add(acc, product.total_price)
    end)
  end

  defp calculate_total_common(products) do
    Enum.reduce(products, Decimal.new("0"), fn product, acc ->
      # Legacy is_common support
      legacy_common_cost =
        if product.is_common do
          product.total_price
        else
          Decimal.new("0")
        end

      # New common_units support
      common_units = product.common_units || Decimal.new("0")

      common_units_cost =
        if Decimal.compare(common_units, Decimal.new("0")) == :gt do
          unit_cost = Decimal.div(product.total_price, Decimal.new(product.units))
          Decimal.mult(unit_cost, common_units)
        else
          Decimal.new("0")
        end

      # Sum common costs
      product_common_total = Decimal.add(legacy_common_cost, common_units_cost)
      Decimal.add(acc, product_common_total)
    end)
  end

  defp requires_unshare_confirmation?(
         products,
         product_id,
         participant_name,
         target_group_id
       ) do
    product = Enum.find(products, fn p -> to_string(p.id) == to_string(product_id) end)

    if product do
      assignments =
        Enum.filter(product.participant_assignments, fn pa ->
          pa.participant_name == participant_name
        end)

      if target_group_id do
        # Case A: User clicked a specific card (group_id provided)
        target_assignment =
          Enum.find(assignments, fn pa -> pa.assignment_group_id == target_group_id end)

        if target_assignment do
          is_shared_group?(product, target_assignment.assignment_group_id)
        else
          false
        end
      else
        # Case B: User clicked generic Remove button (no group_id)
        # Check if we have ANY solo assignment to remove first (priority)
        has_solo =
          Enum.any?(assignments, fn pa ->
            !is_shared_group?(product, pa.assignment_group_id)
          end)

        if has_solo do
          false
        else
          # If no solo assignments, but we have shared ones, we need confirmation
          Enum.any?(assignments, fn pa ->
            is_shared_group?(product, pa.assignment_group_id)
          end)
        end
      end
    else
      false
    end
  end

  defp is_shared_group?(_product, nil), do: false

  defp is_shared_group?(product, group_id) do
    count =
      Enum.count(product.participant_assignments, fn pa ->
        pa.assignment_group_id == group_id
      end)

    count > 1
  end

  # Obtiene el color existente de un usuario basado en sus asignaciones previas
  defp get_existing_user_color(ticket_id, participant_name) do
    # Buscar todas las asignaciones del usuario en este ticket
    assignments =
      TicketSplitter.Tickets.get_participant_assignments_by_ticket(ticket_id, participant_name)

    # Si tiene asignaciones, usar el color de la primera
    case assignments do
      [first_assignment | _] -> first_assignment.assigned_color
      [] -> nil
    end
  end

  # Genera un color determinista basado en el nombre del usuario
  defp get_deterministic_color(name, existing_participants) do
    # Obtener colores ya usados
    used_colors = Enum.map(existing_participants, & &1.color)

    # Generar hash del nombre para obtener siempre el mismo índice
    name_hash = :erlang.phash2(name)
    color_index = rem(name_hash, length(@colors))

    # Encontrar un color disponible empezando desde el índice determinista
    color = get_available_color_from_index(color_index, used_colors)

    color
  end

  # Encuentra el siguiente color disponible desde un índice inicial
  defp get_available_color_from_index(start_index, used_colors) do
    # Probar colores desde el índice inicial en adelante
    {color, _} =
      Stream.iterate(start_index, &rem(&1 + 1, length(@colors)))
      |> Stream.map(&Enum.at(@colors, &1))
      |> Stream.reject(&(&1 in used_colors))
      |> Enum.take(1)
      |> List.pop_at(0) || {Enum.at(@colors, start_index), start_index}

    color
  end

  defp build_ticket_page_title(ticket) do
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

  defp build_ticket_page_description(ticket, total_ticket) do
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
end
