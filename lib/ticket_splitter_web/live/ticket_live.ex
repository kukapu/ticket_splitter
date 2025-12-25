defmodule TicketSplitterWeb.TicketLive do
  use TicketSplitterWeb, :live_view

  alias TicketSplitter.Tickets
  alias TicketSplitter.Tickets.{TicketColorManager, TicketBroadcaster}
  alias TicketSplitterWeb.TicketLive.{Helpers, SliderActions, ParticipantActions, ProductActions, MultiplierActions, ActingAsActions, ModalActions, ConfirmationActions, ParticipantsCountActions, ToggleActions, ParticipantSelectorActions, SocketStateActions, SliderInfoActions, ParticipantsUpdateActions, MountActions, TicketUpdateInfoActions, SliderEventActions, TerminateActions}

  @impl true
  def mount(%{"id" => ticket_id}, _session, socket) do
    # Suscribirse al tópico del ticket para recibir actualizaciones en tiempo real
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TicketSplitter.PubSub, "ticket:#{ticket_id}")
    end

    ticket = Tickets.get_ticket_with_products!(ticket_id)

    # Calcular saldos iniciales
    {total_ticket, total_assigned, pending} =
      MountActions.calculate_initial_saldos(ticket.products, ticket.total_participants)

    # Calcular el número mínimo de participantes
    min_participants = MountActions.calculate_min_participants(ticket_id)

    # Generar metadatos de página
    page_metadata =
      MountActions.build_page_metadata_assigns(ticket, total_ticket)

    socket =
      socket
      |> assign(MountActions.build_initial_socket_assigns(
        ticket,
        total_ticket,
        total_assigned,
        pending,
        min_participants,
        page_metadata
      ))

    # Save ticket to history when visiting (only when connected to prevent double-save)
    socket =
      if connected?(socket) do
        push_event(socket, "save_ticket_to_history", %{
          ticket: MountActions.build_ticket_history_map(ticket)
        })
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("set_participant_name", %{"name" => name}, socket) do
    name = String.trim(name)
    existing_participants = Tickets.get_ticket_participants(socket.assigns.ticket.id)

    color = ParticipantActions.get_participant_color(socket.assigns.ticket.id, name, existing_participants)
    final_participants_count = ParticipantActions.calculate_new_participants_count(existing_participants, name)

    ticket =
      case ParticipantActions.should_update_participants_count?(
             socket.assigns.ticket.total_participants,
             final_participants_count
           ) do
        {:should_update, new_count} ->
          {:ok, updated_ticket} = Tickets.update_ticket(socket.assigns.ticket, %{total_participants: new_count})
          TicketBroadcaster.broadcast_ticket_update(socket.assigns.ticket.id)
          updated_ticket

        :no_update ->
          socket.assigns.ticket
      end

    socket =
      socket
      |> assign(ParticipantActions.build_participant_assigns(name, color, ticket))
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

    if old_name == new_name do
      {:noreply, socket}
    else
      existing_participants = Tickets.get_ticket_participants(ticket_id)

      case ParticipantActions.determine_name_change_action(ticket_id, old_name, new_name, existing_participants) do
        {:error, :name_conflict} ->
          socket =
            socket
            |> put_flash(
              :error,
              gettext("This name is already being used by another participant with assigned items")
            )
            |> push_event("name_change_error", %{})

          {:noreply, socket}

        {:update_db, _color} ->
          case Tickets.update_participant_name(ticket_id, old_name, new_name) do
            {:ok, _count} ->
              TicketBroadcaster.broadcast_ticket_update(ticket_id)
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

        {:adopt, color} ->
          socket =
            socket
            |> assign(:participant_name, new_name)
            |> assign(:participant_color, color)
            |> push_event("save_participant_name", %{name: new_name})
            |> push_event("name_change_success", %{})
            |> calculate_my_total()
            |> update_main_saldos()

          {:noreply, socket}

        {:change_only, color} ->
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

          if Helpers.requires_unshare_confirmation?(
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

    socket = assign(socket, ConfirmationActions.hide_unshare_confirmation_assigns())
    execute_toggle_action("remove_unit", params, socket)
  end

  def handle_event("cancel_unshare", _params, socket) do
    {:noreply, assign(socket, ConfirmationActions.hide_unshare_confirmation_assigns())}
  end

  def handle_event("confirm_share", _params, socket) do
    params = socket.assigns.pending_share_action

    socket = assign(socket, ConfirmationActions.hide_share_confirmation_assigns())
    execute_toggle_action("join_group", params, socket)
  end

  def handle_event("cancel_share", _params, socket) do
    {:noreply, assign(socket, ConfirmationActions.hide_share_confirmation_assigns())}
  end

  @impl true
  def handle_event("toggle_common", %{"product_id" => product_id}, socket) do
    result = ProductActions.toggle_common(socket.assigns.ticket.id, product_id)

    socket =
      socket
      |> assign(ProductActions.result_to_assigns(result))
      |> calculate_my_total()
      |> update_main_saldos()

    {:noreply, socket}
  end

  @impl true
  def handle_event("make_common", %{"product_id" => product_id}, socket) do
    result = ProductActions.add_common_units(socket.assigns.ticket.id, product_id, 1)

    socket =
      socket
      |> assign(ProductActions.result_to_assigns(result))
      |> calculate_my_total()
      |> update_main_saldos()

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_from_common", %{"product_id" => product_id}, socket) do
    result = ProductActions.remove_from_common(socket.assigns.ticket.id, product_id)

    socket =
      socket
      |> assign(ProductActions.result_to_assigns(result))
      |> calculate_my_total()
      |> update_main_saldos()

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_common_unit", %{"product_id" => product_id}, socket) do
    result = ProductActions.add_common_units(socket.assigns.ticket.id, product_id, 1)

    socket =
      socket
      |> assign(ProductActions.result_to_assigns(result))
      |> calculate_my_total()
      |> update_main_saldos()

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_common_unit", %{"product_id" => product_id}, socket) do
    result = ProductActions.remove_common_units(socket.assigns.ticket.id, product_id, 1)

    socket =
      socket
      |> assign(ProductActions.result_to_assigns(result))
      |> calculate_my_total()
      |> update_main_saldos()

    {:noreply, socket}
  end

  @impl true
  def handle_event("increment_participants", _params, socket) do
    new_count = ParticipantsCountActions.calculate_increment(socket.assigns.ticket.total_participants)
    update_participants_count(new_count, socket)
  end

  @impl true
  def handle_event("decrement_participants", _params, socket) do
    new_count = ParticipantsCountActions.calculate_decrement(socket.assigns.ticket.total_participants, socket.assigns.min_participants)
    update_participants_count(new_count, socket)
  end

  @impl true
  def handle_event("update_total_participants", %{"value" => value}, socket) do
    case ParticipantsCountActions.parse_and_validate_value(value, socket.assigns.min_participants) do
      {:ok, num} ->
        update_participants_count(num, socket)

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_summary", _params, socket) do
    participants = get_all_participants(socket.assigns)

    summary_assigns =
      TicketUpdateInfoActions.build_summary_assigns(
        socket.assigns.ticket.id,
        socket.assigns.ticket,
        socket.assigns.participant_name,
        participants
      )

    socket =
      socket
      |> assign(:show_summary_modal, true)
      |> assign(:summary_tab, "summary")
      |> assign(summary_assigns)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_summary", _params, socket) do
    {:noreply, assign(socket, ModalActions.close_modal_assigns(:show_summary_modal))}
  end

  @impl true
  def handle_event("toggle_instructions", _params, socket) do
    {:noreply, assign(socket, ModalActions.toggle_modal_assigns(:show_instructions, socket.assigns.show_instructions))}
  end

  @impl true
  def handle_event("open_share_modal", _params, socket) do
    {:noreply, assign(socket, ModalActions.open_modal_assigns(:show_share_modal))}
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply, assign(socket, ModalActions.close_modal_assigns(:show_share_modal))}
  end

  @impl true
  def handle_event("open_image_modal", _params, socket) do
    {:noreply, assign(socket, ModalActions.open_modal_assigns(:show_image_modal))}
  end

  @impl true
  def handle_event("close_image_modal", _params, socket) do
    {:noreply, assign(socket, ModalActions.close_modal_assigns(:show_image_modal))}
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
    {active_participant, _color} = get_active_participant(socket)

    if SliderActions.has_lock?(socket.assigns.locked_sliders, group_id, active_participant) do
      case SliderEventActions.execute_split_percentage_update(
             socket.assigns.ticket.id,
             group_id,
             p1_percentage,
             p2_percentage
           ) do
        {:ok, ticket} ->
          acting_as_assigns =
            SliderEventActions.build_acting_as_total_assigns(
              socket.assigns.ticket.id,
              socket.assigns.acting_as_participant
            )

          socket =
            socket
            |> assign(:ticket, ticket)
            |> assign(:products, ticket.products)
            |> assign(acting_as_assigns)
            |> calculate_my_total()
            |> update_main_saldos()

          {:noreply, socket}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lock_slider", %{"group_id" => group_id}, socket) do
    {active_participant, _color} = get_active_participant(socket)

    case SliderActions.can_acquire_lock?(socket.assigns.locked_sliders, group_id, active_participant) do
      true ->
        locked_sliders = SliderActions.acquire_lock(socket.assigns.locked_sliders, group_id, active_participant)
        TicketBroadcaster.broadcast_slider_lock(socket.assigns.ticket.id, group_id, active_participant)
        {:noreply, assign(socket, :locked_sliders, locked_sliders)}

      :already_locked ->
        {:noreply, socket}

      false ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unlock_slider", %{"group_id" => group_id}, socket) do
    {active_participant, _color} = get_active_participant(socket)
    locked_sliders = SliderActions.release_lock(socket.assigns.locked_sliders, group_id, active_participant)

    if locked_sliders != socket.assigns.locked_sliders do
      TicketBroadcaster.broadcast_slider_unlock(socket.assigns.ticket.id, group_id)
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
    case SliderEventActions.execute_save_percentages(socket.assigns.ticket.id, assignments_map) do
      {:ok, ticket} ->
        socket =
          socket
          |> assign(SliderEventActions.build_save_percentages_assigns(ticket))
          |> calculate_my_total()
          |> update_main_saldos()

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("participant_name_from_storage", %{"name" => name}, socket) do
    if name && name != "" do
      handle_event("set_participant_name", %{"name" => name}, socket)
    else
      existing_participants = Tickets.get_ticket_participants(socket.assigns.ticket.id)

      if Enum.empty?(existing_participants) do
        {:noreply, push_event(socket, "open_user_settings_modal", %{})}
      else
        participants_with_colors =
          ParticipantActions.prepare_participants_for_selector(socket.assigns.ticket.id, existing_participants)

        {:noreply,
         socket
         |> assign(:show_participant_selector, true)
         |> assign(:existing_participants_for_selector, participants_with_colors)}
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
    {:noreply,
     socket
     |> assign(ParticipantSelectorActions.close_selector_assigns())
     |> push_event("open_user_settings_modal", %{})}
  end

  @impl true
  def handle_event("close_participant_selector", _params, socket) do
    {:noreply, assign(socket, ParticipantSelectorActions.close_selector_assigns())}
  end

  # Multiplier events - now applies to the active user (acting_as or self)
  @impl true
  def handle_event("update_my_multiplier", %{"multiplier" => multiplier_str}, socket) do
    target_participant = MultiplierActions.get_target_participant(socket)

    if target_participant do
      case Integer.parse(multiplier_str) do
        {new_multiplier, _} when new_multiplier > 0 and new_multiplier <= 10 ->
          old_multiplier = MultiplierActions.get_current_multiplier(socket)
          multiplier_diff = new_multiplier - old_multiplier

          case Tickets.update_participant_multiplier(
                 socket.assigns.ticket.id,
                 target_participant,
                 new_multiplier
               ) do
            {:ok, _} ->
              new_total_participants =
                MultiplierActions.calculate_new_total_participants(socket, multiplier_diff)

              {:ok, updated_ticket} =
                Tickets.update_ticket(socket.assigns.ticket, %{total_participants: new_total_participants})

              TicketBroadcaster.broadcast_ticket_update(socket.assigns.ticket.id)

              assigns =
                if socket.assigns.acting_as_participant do
                  MultiplierActions.build_acting_as_assigns(
                    socket.assigns.ticket.id,
                    socket.assigns.acting_as_participant,
                    new_multiplier
                  )
                else
                  MultiplierActions.build_self_assigns(new_multiplier)
                end

              socket
              |> assign(:ticket, updated_ticket)
              |> assign(assigns)
              |> calculate_my_total()
              |> update_main_saldos()

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
    current_multiplier = MultiplierActions.get_current_multiplier(socket)
    new_multiplier = min(current_multiplier + 1, 10)
    handle_event("update_my_multiplier", %{"multiplier" => to_string(new_multiplier)}, socket)
  end

  @impl true
  def handle_event("decrement_multiplier", _params, socket) do
    current_multiplier = MultiplierActions.get_current_multiplier(socket)
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
    name = String.trim(name)
    existing_participants = Tickets.get_ticket_participants(socket.assigns.ticket.id)

    participant = ActingAsActions.find_participant_by_name(existing_participants, name)

    if participant do
      assigns =
        ActingAsActions.build_acting_as_assigns(socket.assigns.ticket.id, name, participant.color)

      {:noreply, assign(socket, assigns)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_acting_as", _params, socket) do
    {:noreply, assign(socket, ActingAsActions.build_clear_acting_as_assigns())}
  end

  @impl true
  def handle_event("create_ghost_participant", %{"name" => name}, socket) do
    name = String.trim(name)

    if name != "" do
      existing_participants = Tickets.get_ticket_participants(socket.assigns.ticket.id)

      if ActingAsActions.ghost_name_exists?(existing_participants, name) do
        {:noreply, socket}
      else
        color = TicketColorManager.get_deterministic_color(name, existing_participants)

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
    if ticket_id == socket.assigns.ticket.id do
      ticket = Tickets.get_ticket_with_products!(ticket_id)
      min_participants = TicketUpdateInfoActions.calculate_min_participants(ticket_id)

      socket =
        if TicketUpdateInfoActions.should_update_summary?(socket.assigns.show_summary_modal) do
          participants = get_all_participants(socket.assigns)

          summary_assigns =
            TicketUpdateInfoActions.build_summary_assigns(
              socket.assigns.ticket.id,
              ticket,
              socket.assigns.participant_name,
              participants
            )

          socket
          |> assign(summary_assigns)
          |> assign(:min_participants, min_participants)
          |> calculate_my_total()
          |> update_main_saldos()
        else
          socket
          |> assign(TicketUpdateInfoActions.build_basic_assigns(ticket))
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
    socket =
      socket
      |> assign(SliderInfoActions.slider_locked_assigns(socket.assigns.locked_sliders, group_id, locked_by))
      |> push_event("slider_locked", %{group_id: group_id, locked_by: locked_by})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:slider_unlocked, group_id}, socket) do
    socket =
      socket
      |> assign(SliderInfoActions.slider_unlocked_assigns(socket.assigns.locked_sliders, group_id))
      |> push_event("slider_unlocked", %{group_id: group_id})

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    TerminateActions.unlock_participant_sliders(
      socket.assigns.ticket.id,
      socket.assigns.participant_name,
      socket.assigns.locked_sliders
    )
  end

  defp execute_toggle_action(action, params, socket) do
    {participant_name, color} = get_active_participant(socket)
    product_id = Map.get(params, "product_id")

    participant_count_before =
      if ToggleActions.should_count_participants_before?(action) do
        length(Tickets.get_ticket_participants(socket.assigns.ticket.id))
      else
        nil
      end

    result = ToggleActions.execute_action(action, product_id, participant_name, color, params)

    case result do
      {:ok, _} ->
        TicketBroadcaster.broadcast_ticket_update(socket.assigns.ticket.id)
        ticket = Tickets.get_ticket_with_products!(socket.assigns.ticket.id)

        real_participants_count = length(Tickets.get_ticket_participants(socket.assigns.ticket.id))
        min_participants = max(real_participants_count, 1)

        socket =
          socket
          |> assign(:ticket, ticket)
          |> assign(:products, ticket.products)
          |> assign(:min_participants, min_participants)
          |> calculate_my_total()
          |> update_main_saldos()

        # Update total_participants if new participant added
        case ToggleActions.update_total_if_new_participant(socket, participant_count_before, real_participants_count, ticket) do
          {:ok, updated_ticket} ->
            socket = assign(socket, :ticket, updated_ticket)

            socket =
              if socket.assigns.acting_as_participant do
                acting_as_total = ToggleActions.recalculate_acting_as_total(socket.assigns.ticket.id, socket.assigns.acting_as_participant)
                assign(socket, :acting_as_total, acting_as_total)
              else
                socket
              end

            {:noreply, socket}

          _ ->
            {:noreply, socket}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp update_participants_count(new_count, socket) do
    case ParticipantsUpdateActions.execute_update_and_broadcast(socket.assigns.ticket, new_count) do
      {:ok, ticket} ->
        socket =
          if socket.assigns.show_summary_modal do
            participants = get_all_participants(socket.assigns)

            summary_assigns =
              ParticipantsUpdateActions.build_summary_modal_assigns(
                socket.assigns.products,
                new_count,
                socket.assigns.ticket.id,
                participants,
                ticket
              )

            socket
            |> assign(summary_assigns)
            |> calculate_my_total()
            |> update_main_saldos()
          else
            socket
            |> assign(ParticipantsUpdateActions.build_basic_assigns(ticket))
            |> calculate_my_total()
            |> update_main_saldos()
          end

        {:noreply, socket}

      :error ->
        {:noreply, socket}
    end
  end

  # Private functions

  defp get_active_participant(socket) do
    {
      SocketStateActions.get_active_participant_name(socket),
      SocketStateActions.get_active_participant_color(socket)
    }
  end

  defp format_decimal(decimal), do: Helpers.format_decimal(decimal)

  defp group_assignments_by_group_id(assignments), do: Helpers.group_assignments_by_group_id(assignments)

  defp get_all_participants(%{assigns: assigns}) do
    Helpers.get_all_participants_from_db(assigns.ticket.id)
  end

  defp get_all_participants(assigns) when is_map(assigns) do
    Helpers.get_all_participants_from_db(assigns.ticket.id)
  end

  defp calculate_my_total(socket) do
    assigns = SocketStateActions.calculate_my_total_assigns(socket.assigns.ticket.id, socket.assigns.participant_name)
    assign(socket, assigns)
  end

  defp update_main_saldos(socket) do
    assigns = SocketStateActions.calculate_main_saldos_assigns(socket.assigns.products, socket.assigns.ticket.total_participants)
    assign(socket, assigns)
  end
end
