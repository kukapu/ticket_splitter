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
      |> assign(:show_summary_modal, false)
      |> assign(:show_share_modal, false)
      |> assign(:show_image_modal, false)
      |> assign(:show_participant_selector, false)
      |> assign(:existing_participants_for_selector, [])
      |> assign(:show_instructions, false)
      |> assign(:show_share_confirmation, false)
      |> assign(:show_unshare_confirmation, false)
      |> assign(:pending_share_action, nil)
      |> assign(:editing_percentages_product_id, nil)
      |> assign(:my_total, Decimal.new("0"))
      |> assign(:my_multiplier, 1)
      |> assign(:acting_as_participant, nil)
      |> assign(:acting_as_color, nil)
      |> assign(:acting_as_total, Decimal.new("0"))
      |> assign(:acting_as_multiplier, 1)
      # "summary" or "assign"
      |> assign(:summary_tab, "summary")
      |> assign(:total_ticket_main, total_ticket)
      |> assign(:total_assigned_main, total_assigned)
      |> assign(:pending_main, pending)
      |> assign(:min_participants, min_participants)
      |> assign(:locked_sliders, %{})
      |> assign(:page_title, page_title)
      |> assign(:page_description, page_description)
      |> assign(:page_url, page_url)

    # Save ticket to history when visiting (only when connected to prevent double-save)
    socket =
      if connected?(socket) do
        push_event(socket, "save_ticket_to_history", %{
          ticket: %{
            id: ticket.id,
            merchant_name: ticket.merchant_name,
            date: ticket.date
          }
        })
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("set_participant_name", %{"name" => name}, socket) do
    # Normalize name to lowercase for case-insensitive comparison
    name = String.trim(name)

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
        "change_participant_name",
        %{"old_name" => old_name, "new_name" => new_name},
        socket
      ) do
    old_name = String.trim(old_name)
    new_name = String.trim(new_name)

    ticket_id = socket.assigns.ticket.id

    # Caso 1: Mismo nombre - no hacer nada
    if old_name == new_name do
      {:noreply, socket}
    else
      # Verificar si tengo asignaciones con el nombre antiguo
      has_assignments = Tickets.participant_has_assignments?(ticket_id, old_name)

      # Verificar si el nuevo nombre ya existe
      name_exists = Tickets.participant_name_exists?(ticket_id, new_name)

      cond do
        # Caso 2: Tengo asignaciones Y el nuevo nombre ya existe -> ERROR
        has_assignments && name_exists ->
          socket =
            socket
            |> put_flash(
              :error,
              gettext(
                "This name is already being used by another participant with assigned items"
              )
            )
            |> push_event("name_change_error", %{})

          {:noreply, socket}

        # Caso 3: Tengo asignaciones Y el nuevo nombre NO existe -> ACTUALIZAR
        has_assignments && !name_exists ->
          case Tickets.update_participant_name(ticket_id, old_name, new_name) do
            {:ok, _count} ->
              # Broadcast para actualizar a todos los usuarios
              broadcast_ticket_update(ticket_id)

              # Recargar ticket
              ticket = Tickets.get_ticket_with_products!(ticket_id)

              socket =
                socket
                |> assign(:ticket, ticket)
                |> assign(:participant_name, new_name)
                |> push_event("save_participant_name", %{name: new_name})
                |> push_event("name_change_success", %{})
                |> calculate_my_total()
                |> update_main_saldos()

              {:noreply, socket}

            {:error, _} ->
              socket =
                socket
                |> put_flash(:error, gettext("Failed to update name"))
                |> push_event("name_change_error", %{})

              {:noreply, socket}
          end

        # Caso 4: NO tengo asignaciones Y el nuevo nombre ya existe -> ADOPTAR
        !has_assignments && name_exists ->
          # Simplemente cambiar al nuevo nombre (adoptarlo)
          existing_user_color = get_existing_user_color(ticket_id, new_name)
          existing_participants = Tickets.get_ticket_participants(ticket_id)

          color =
            if existing_user_color do
              existing_user_color
            else
              get_deterministic_color(new_name, existing_participants)
            end

          socket =
            socket
            |> assign(:participant_name, new_name)
            |> assign(:participant_color, color)
            |> push_event("save_participant_name", %{name: new_name})
            |> push_event("name_change_success", %{})
            |> calculate_my_total()
            |> update_main_saldos()

          {:noreply, socket}

        # Caso 5: NO tengo asignaciones Y el nuevo nombre NO existe -> CAMBIAR
        !has_assignments && !name_exists ->
          existing_participants = Tickets.get_ticket_participants(ticket_id)
          color = get_deterministic_color(new_name, existing_participants)

          socket =
            socket
            |> assign(:participant_name, new_name)
            |> assign(:participant_color, color)
            |> push_event("save_participant_name", %{name: new_name})
            |> push_event("name_change_success", %{})
            |> calculate_my_total()
            |> update_main_saldos()

          {:noreply, socket}
      end
    end
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
      # Usar la misma lógica que cuando no hay nombre en localStorage
      handle_event("participant_name_from_storage", %{"name" => ""}, socket)
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
    current_participant_name = socket.assigns.participant_name

    participant_summaries =
      Enum.map(participants, fn participant ->
        calculate_participant_summary(socket.assigns.ticket.id, participant)
      end)

    # Sort: current user first, then alphabetically
    sorted_summaries =
      Enum.sort_by(participant_summaries, fn summary ->
        if summary.name == current_participant_name do
          # Current user comes first
          {0, summary.name}
        else
          {1, summary.name}
        end
      end)

    total_ticket = calculate_ticket_total(socket.assigns.products)

    total_assigned =
      calculate_total_assigned(socket.assigns.products, socket.assigns.ticket.total_participants)

    pending = Decimal.sub(total_ticket, total_assigned)

    # Calculate "Rest of participants" if applicable
    # IMPORTANT: active_count now considers multipliers
    # (if someone has multiplier 4, they count as 4 active participants)
    active_multipliers_sum =
      Enum.reduce(sorted_summaries, 0, fn summary, acc ->
        acc + (summary.multiplier || 1)
      end)

    total_participants = socket.assigns.ticket.total_participants

    # Add "Rest of participants" summary if there are more total participants than effective active ones
    final_summaries =
      if total_participants > active_multipliers_sum do
        rest_count = total_participants - active_multipliers_sum

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
          multiplier: 1,
          is_rest: true
        }

        # Add rest summary to the list, but keep original total_assigned and pending
        sorted_summaries ++ [rest_summary]
      else
        sorted_summaries
      end

    {:noreply,
     socket
     |> assign(:show_summary_modal, true)
     # Reset to summary tab when opening
     |> assign(:summary_tab, "summary")
     |> assign(:participants_for_summary, final_summaries)
     |> assign(:total_ticket_for_summary, total_ticket)
     |> assign(:total_assigned_for_summary, total_assigned)
     |> assign(:pending_for_summary, pending)}
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
  def handle_event("open_image_modal", _params, socket) do
    {:noreply, assign(socket, :show_image_modal, true)}
  end

  @impl true
  def handle_event("close_image_modal", _params, socket) do
    {:noreply, assign(socket, :show_image_modal, false)}
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
    {active_participant, _color} = get_active_participant(socket)
    locked_by = Map.get(socket.assigns.locked_sliders, group_id)

    if locked_by == active_participant do
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

          # Also recalculate acting_as_total if in acting_as mode
          socket =
            if socket.assigns.acting_as_participant do
              acting_as_total =
                Tickets.calculate_participant_total_with_multiplier(
                  socket.assigns.ticket.id,
                  socket.assigns.acting_as_participant
                )

              assign(socket, :acting_as_total, acting_as_total)
            else
              socket
            end

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
    {active_participant, _color} = get_active_participant(socket)

    # Check if slider is already locked
    case Map.get(socket.assigns.locked_sliders, group_id) do
      nil ->
        # Not locked, acquire lock
        locked_sliders = Map.put(socket.assigns.locked_sliders, group_id, active_participant)

        # Broadcast lock to all users
        broadcast_slider_lock(socket.assigns.ticket.id, group_id, active_participant)

        {:noreply, assign(socket, :locked_sliders, locked_sliders)}

      ^active_participant ->
        # Already locked by this user, nothing to do
        {:noreply, socket}

      _other_user ->
        # Locked by another user, reject
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unlock_slider", %{"group_id" => group_id}, socket) do
    {active_participant, _color} = get_active_participant(socket)
    locked_by = Map.get(socket.assigns.locked_sliders, group_id)

    # Only unlock if this user has the lock
    if locked_by == active_participant do
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
      # Sin nombre - decidir qué hacer según los participantes existentes
      existing_participants = Tickets.get_ticket_participants(socket.assigns.ticket.id)

      if Enum.empty?(existing_participants) do
        # No hay participantes - abrir directamente el modal del header
        socket =
          socket
          |> push_event("open_user_settings_modal", %{})

        {:noreply, socket}
      else
        # Hay participantes - mostrar modal de selección con colores
        participants_with_colors =
          Enum.map(existing_participants, fn p ->
            %{
              name: p.name,
              color:
                get_existing_user_color(socket.assigns.ticket.id, p.name) ||
                  get_deterministic_color(p.name, existing_participants)
            }
          end)

        socket =
          socket
          |> assign(:show_participant_selector, true)
          |> assign(:existing_participants_for_selector, participants_with_colors)

        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("select_existing_participant", %{"name" => name}, socket) do
    # Usuario selecciona un participante existente
    socket =
      socket
      |> assign(:show_participant_selector, false)
      |> assign(:existing_participants_for_selector, [])

    handle_event("set_participant_name", %{"name" => name}, socket)
  end

  @impl true
  def handle_event("create_new_participant", _params, socket) do
    # Usuario quiere crear nuevo - abrir el modal del header
    socket =
      socket
      |> assign(:show_participant_selector, false)
      |> assign(:existing_participants_for_selector, [])
      |> push_event("open_user_settings_modal", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_participant_selector", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_participant_selector, false)
     |> assign(:existing_participants_for_selector, [])}
  end

  # Multiplier events - now applies to the active user (acting_as or self)
  @impl true
  def handle_event("update_my_multiplier", %{"multiplier" => multiplier_str}, socket) do
    # Determine which participant to update: acting_as if set, otherwise self
    target_participant = socket.assigns.acting_as_participant || socket.assigns.participant_name

    if target_participant do
      case Integer.parse(multiplier_str) do
        {new_multiplier, _} when new_multiplier > 0 and new_multiplier <= 10 ->
          old_multiplier =
            if socket.assigns.acting_as_participant do
              Tickets.get_participant_multiplier(
                socket.assigns.ticket.id,
                socket.assigns.acting_as_participant
              )
            else
              socket.assigns.my_multiplier
            end

          multiplier_diff = new_multiplier - old_multiplier

          case Tickets.update_participant_multiplier(
                 socket.assigns.ticket.id,
                 target_participant,
                 new_multiplier
               ) do
            {:ok, _} ->
              # Also update total_participants to reflect the multiplier change
              ticket = socket.assigns.ticket

              new_total_participants =
                max(ticket.total_participants + multiplier_diff, socket.assigns.min_participants)

              {:ok, updated_ticket} =
                Tickets.update_ticket(ticket, %{total_participants: new_total_participants})

              # Broadcast update to all users
              broadcast_ticket_update(socket.assigns.ticket.id)

              # Recalculate totals - different based on who we updated
              socket = assign(socket, :ticket, updated_ticket)

              socket =
                if socket.assigns.acting_as_participant do
                  # Updated the acting_as user, recalculate their total
                  acting_as_total =
                    Tickets.calculate_participant_total_with_multiplier(
                      socket.assigns.ticket.id,
                      socket.assigns.acting_as_participant
                    )

                  socket
                  |> assign(:acting_as_total, acting_as_total)
                  |> assign(:acting_as_multiplier, new_multiplier)
                  |> calculate_my_total()
                  |> update_main_saldos()
                else
                  # Updated self
                  socket
                  |> assign(:my_multiplier, new_multiplier)
                  |> calculate_my_total()
                  |> update_main_saldos()
                end

              {:noreply, socket}

            {:error, _} ->
              {:noreply, socket}
          end

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("increment_multiplier", _params, socket) do
    # Get current multiplier of active user
    current_multiplier =
      if socket.assigns.acting_as_participant do
        Tickets.get_participant_multiplier(
          socket.assigns.ticket.id,
          socket.assigns.acting_as_participant
        )
      else
        socket.assigns.my_multiplier
      end

    new_multiplier = min(current_multiplier + 1, 10)
    handle_event("update_my_multiplier", %{"multiplier" => to_string(new_multiplier)}, socket)
  end

  @impl true
  def handle_event("decrement_multiplier", _params, socket) do
    # Get current multiplier of active user
    current_multiplier =
      if socket.assigns.acting_as_participant do
        Tickets.get_participant_multiplier(
          socket.assigns.ticket.id,
          socket.assigns.acting_as_participant
        )
      else
        socket.assigns.my_multiplier
      end

    new_multiplier = max(current_multiplier - 1, 1)
    handle_event("update_my_multiplier", %{"multiplier" => to_string(new_multiplier)}, socket)
  end

  # Tab events for summary modal
  @impl true
  def handle_event("switch_summary_tab", %{"tab" => tab}, socket)
      when tab in ["summary", "assign"] do
    {:noreply, assign(socket, :summary_tab, tab)}
  end

  @impl true
  def handle_event("set_acting_as", %{"name" => name}, socket) do
    # Set to act as another participant
    name = String.trim(name)
    existing_participants = Tickets.get_ticket_participants(socket.assigns.ticket.id)

    participant = Enum.find(existing_participants, fn p -> p.name == name end)

    if participant do
      # Calculate the total for the acting_as participant
      acting_as_total =
        Tickets.calculate_participant_total_with_multiplier(socket.assigns.ticket.id, name)

      acting_as_multiplier =
        Tickets.get_participant_multiplier(socket.assigns.ticket.id, name)

      {:noreply,
       socket
       |> assign(:acting_as_participant, name)
       |> assign(:acting_as_color, participant.color)
       |> assign(:acting_as_total, acting_as_total)
       |> assign(:acting_as_multiplier, acting_as_multiplier)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_acting_as", _params, socket) do
    # Return to acting as self
    {:noreply,
     socket
     |> assign(:acting_as_participant, nil)
     |> assign(:acting_as_color, nil)
     |> assign(:acting_as_total, Decimal.new("0"))
     |> assign(:acting_as_multiplier, 1)}
  end

  @impl true
  def handle_event("create_ghost_participant", %{"name" => name}, socket) do
    # Create a new "ghost" participant and set acting as them
    name = String.trim(name)

    if name != "" do
      existing_participants = Tickets.get_ticket_participants(socket.assigns.ticket.id)

      # Check if already exists
      if Enum.any?(existing_participants, fn p -> p.name == name end) do
        {:noreply, socket}
      else
        # Generate a color for the ghost
        color = get_deterministic_color(name, existing_participants)

        {:noreply,
         socket
         |> assign(:acting_as_participant, name)
         |> assign(:acting_as_color, color)
         |> assign(:show_avatar_switcher, false)}
      end
    else
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

  defp execute_toggle_action(action, params, socket) do
    # Use acting_as_participant if in admin mode, otherwise use own participant
    {participant_name, color} = get_active_participant(socket)
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

        # Also recalculate acting_as_total if in acting_as mode
        socket =
          if socket.assigns.acting_as_participant do
            acting_as_total =
              Tickets.calculate_participant_total_with_multiplier(
                socket.assigns.ticket.id,
                socket.assigns.acting_as_participant
              )

            assign(socket, :acting_as_total, acting_as_total)
          else
            socket
          end

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

  # Private functions

  defp broadcast_ticket_update(ticket_id) do
    Phoenix.PubSub.broadcast(
      TicketSplitter.PubSub,
      "ticket:#{ticket_id}",
      {:ticket_updated, ticket_id}
    )
  end

  defp get_active_participant(socket) do
    # Returns {participant_name, color} - either acting_as or the user's own
    if socket.assigns.acting_as_participant do
      {socket.assigns.acting_as_participant, socket.assigns.acting_as_color}
    else
      {socket.assigns.participant_name, socket.assigns.participant_color}
    end
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

    if participant_name do
      total =
        Tickets.calculate_participant_total_with_multiplier(
          socket.assigns.ticket.id,
          participant_name
        )

      multiplier = Tickets.get_participant_multiplier(socket.assigns.ticket.id, participant_name)

      socket
      |> assign(:my_total, total)
      |> assign(:my_multiplier, multiplier)
    else
      socket
      |> assign(:my_total, Decimal.new("0"))
      |> assign(:my_multiplier, 1)
    end
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
    total = Tickets.calculate_participant_total_with_multiplier(ticket_id, participant.name)
    multiplier = Tickets.get_participant_multiplier(ticket_id, participant.name)
    %{name: participant.name, color: participant.color, total: total, multiplier: multiplier}
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
