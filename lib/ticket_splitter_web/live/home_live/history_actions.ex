defmodule TicketSplitterWeb.HomeLive.HistoryActions do
  @moduledoc """
  Handles history-related actions for HomeLive.
  """

  import Phoenix.Component, only: [assign: 3]

  @doc """
  Toggles the history panel visibility.
  """
  def toggle_history(socket) do
    {:noreply, assign(socket, :show_history, !socket.assigns.show_history)}
  end

  @doc """
  Loads the ticket history from localStorage.
  """
  def history_loaded(socket, %{"tickets" => tickets}) do
    {:noreply, assign(socket, :ticket_history, tickets)}
  end

  @doc """
  Asks for confirmation before deleting a ticket.
  """
  def ask_delete(socket, %{"id" => id}) do
    {:noreply, assign(socket, :ticket_to_delete, id)}
  end

  @doc """
  Cancels the deletion process.
  """
  def cancel_delete(socket) do
    {:noreply, assign(socket, :ticket_to_delete, nil)}
  end

  @doc """
  Deletes a ticket from the database.
  """
  def delete_ticket(socket, %{"id" => id}) do
    case TicketSplitter.Tickets.get_ticket!(id) do
      nil ->
        {:noreply, socket}

      ticket ->
        TicketSplitter.Tickets.delete_ticket(ticket)
        {:noreply, assign(socket, :ticket_to_delete, nil)}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, assign(socket, :ticket_to_delete, nil)}
  end
end
