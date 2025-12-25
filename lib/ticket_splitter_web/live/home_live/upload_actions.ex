defmodule TicketSplitterWeb.HomeLive.UploadActions do
  @moduledoc """
  Handles upload-related actions for HomeLive.
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]
  require Logger

  alias TicketSplitter.{Storage, ImageProcessor, OpenRouter, Tickets}

  @doc """
  Validates the upload (currently just returns the socket).
  """
  def validate(socket) do
    {:noreply, socket}
  end

  @doc """
  Cancels an upload by reference.
  """
  def cancel_upload(socket, %{"ref" => ref}) do
    {:noreply, Phoenix.LiveView.cancel_upload(socket, :image, ref)}
  end

  @doc """
  Clears the result and error states.
  """
  def clear_result(socket) do
    {:noreply, assign(socket, result: nil, error: nil)}
  end

  @doc """
  Processes a cropped image received from the client.
  Decodes base64, processes the image, uploads to storage, sends to OpenRouter,
  creates the ticket, and redirects to the ticket page.
  """
  def cropped_image_ready(socket, %{
        "base64" => base64,
        "filename" => filename,
        "content_type" => content_type,
        "size" => _size
      }) do
    Logger.info("📥 Received cropped image: #{filename}")

    # Decode base64 to binary
    case Base.decode64(base64) do
      {:ok, binary_data} ->
        process_image_and_create_ticket(socket, binary_data, filename, content_type)

      :error ->
        Logger.error("❌ Failed to decode base64")
        {:noreply, assign(socket, error: "Failed to decode image", processing: false)}
    end
  end

  @doc """
  Handles upload progress (currently not used since we use base64 upload).
  """
  def handle_progress(socket, :image, _entry) do
    {:noreply, socket}
  end

  # Private functions

  defp process_image_and_create_ticket(socket, binary_data, filename, original_content_type) do
    Logger.info("🔄 Processing image and creating ticket...")

    with {:ok, processed_binary, processed_content_type} <- process_image(binary_data),
         {:ok, image_url} <- upload_to_storage(processed_binary, filename, processed_content_type),
         {:ok, uploaded_file} <- prepare_uploaded_file(binary_data, original_content_type),
         {:ok, api_key} <- get_api_key(),
         model <- get_model(),
         {:ok, response} <- send_to_openrouter(uploaded_file, api_key, model),
         {:ok, products_json} <- parse_response(response),
         {:ok, ticket} <- create_ticket(products_json, image_url) do
      Logger.info("✅ Ticket created successfully: #{ticket.id}")

      socket =
        socket
        |> assign(:processing, false)
        |> assign(:result, ticket)
        |> assign(:error, nil)

      locale = socket.assigns[:locale] || "en"
      {:noreply, Phoenix.LiveView.push_navigate(socket, to: "/#{locale}/tickets/#{ticket.id}")}
    else
      {:error, :not_a_receipt, error_message} ->
        Logger.warning("⚠️ Not a receipt: #{error_message}")
        handle_error(socket, error_message)

      {:error, :parsing_failed} ->
        Logger.error("❌ Failed to parse ticket after retries")
        handle_error(socket, "Failed to parse ticket. Please try again.")

      {:error, reason} ->
        Logger.error("❌ Error processing image: #{inspect(reason)}")
        handle_error(socket, "An error occurred while processing your ticket. Please try again.")
    end
  end

  defp process_image(binary_data) do
    Logger.info("🖼️ Processing image (resize, convert to WebP)...")
    ImageProcessor.process(binary_data)
  end

  defp upload_to_storage(binary_data, filename, content_type) do
    Logger.info("☁️ Uploading image to storage...")
    Storage.upload_image(binary_data, filename, content_type)
  end

  defp prepare_uploaded_file(binary_data, content_type) do
    # For OpenRouter, we need to send the original binary as base64
    base64 = Base.encode64(binary_data)

    uploaded_file = %{
      base64: base64,
      content_type: content_type
    }

    {:ok, uploaded_file}
  end

  defp get_api_key do
    case Application.get_env(:ticket_splitter, :openrouter_api_key) do
      nil ->
        Logger.error("❌ OpenRouter API key not configured")
        {:error, :api_key_not_configured}

      api_key ->
        {:ok, api_key}
    end
  end

  defp get_model do
    Application.get_env(:ticket_splitter, :openrouter_model, "openai/gpt-4o-mini")
  end

  defp send_to_openrouter(uploaded_file, api_key, model) do
    Logger.info("🤖 Sending request to OpenRouter with model: #{model}")

    main_prompt = OpenRouter.Prompt.main_prompt()
    validation_prompt = OpenRouter.Prompt.validation_prompt()

    OpenRouter.Validator.validate_with_retry(
      uploaded_file,
      api_key,
      model,
      main_prompt,
      validation_prompt
    )
  end

  defp parse_response(response) do
    Logger.info("📋 Parsing OpenRouter response...")
    OpenRouter.Parser.parse_response(response)
  end

  defp create_ticket(products_json, image_url) do
    Logger.info("🎫 Creating ticket in database...")
    Tickets.create_ticket_from_json(products_json, image_url)
  end

  defp handle_error(socket, error_message) do
    socket =
      socket
      |> assign(:processing, false)
      |> assign(:error, error_message)
      |> assign(:result, nil)

    {:noreply, socket}
  end
end
