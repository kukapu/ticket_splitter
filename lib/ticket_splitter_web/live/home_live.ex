defmodule TicketSplitterWeb.HomeLive do
  use TicketSplitterWeb, :live_view

  alias TicketSplitterWeb.HomeLive.{HistoryActions, UploadActions}

  @impl true
  def mount(_params, _session, socket) do
    alias TicketSplitterWeb.SEO

    socket =
      socket
      |> assign(:uploaded_files, [])
      |> assign(:processing, false)
      |> assign(:result, nil)
      |> assign(:error, nil)
      |> assign(:show_history, false)
      |> assign(:ticket_history, [])
      |> assign(:ticket_to_delete, nil)
      |> assign(:page_title, nil)
      |> assign(
        :page_description,
        gettext(
          "Upload a photo of your ticket and split expenses with your friends automatically. Ticket Splitter analyzes your ticket with AI and helps you split costs fairly."
        )
      )
      |> assign(:page_url, SEO.site_url())
      |> allow_upload(:image,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: 10_000_000,
        auto_upload: false
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    UploadActions.validate(socket)
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    UploadActions.cancel_upload(socket, %{"ref" => ref})
  end

  @impl true
  def handle_event("clear-result", _params, socket) do
    UploadActions.clear_result(socket)
  end

  @impl true
  def handle_event("toggle_history", _params, socket) do
    HistoryActions.toggle_history(socket)
  end

  @impl true
  def handle_event("history_loaded", %{"tickets" => tickets}, socket) do
    HistoryActions.history_loaded(socket, %{"tickets" => tickets})
  end

  @impl true
  def handle_event("ask_delete", %{"id" => id}, socket) do
    HistoryActions.ask_delete(socket, %{"id" => id})
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    HistoryActions.cancel_delete(socket)
  end

  @impl true
  def handle_event("delete_ticket", %{"id" => id}, socket) do
    HistoryActions.delete_ticket(socket, %{"id" => id})
  end

  @impl true
  def handle_event("start_processing", _params, socket) do
    IO.puts("🔄 Iniciando procesamiento - mostrando spinner")
    {:noreply, assign(socket, :processing, true)}
  end

  @impl true
  def handle_event(
        "cropped_image_ready",
        %{
          "base64" => base64,
          "filename" => filename,
          "content_type" => content_type,
          "size" => size
        },
        socket
      ) do
    UploadActions.cropped_image_ready(socket, %{
      "base64" => base64,
      "filename" => filename,
      "content_type" => content_type,
      "size" => size
    })
  end

  def handle_progress(:image, entry, socket) do
    UploadActions.handle_progress(socket, :image, entry)
  end
end
