defmodule TicketSplitterWeb.HomeLive do
  use TicketSplitterWeb, :live_view

  alias TicketSplitter.Tickets
  alias TicketSplitter.OpenRouter.{Parser, Validator, Prompt}

  # Intentos maximos de validación cruzada
  @max_retries 3

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
    IO.puts("🔍 Validating upload...")
    IO.puts("📝 Entries: #{length(socket.assigns.uploads.image.entries)}")

    Enum.each(socket.assigns.uploads.image.entries, fn entry ->
      IO.puts("  - Entry: #{entry.client_name} (#{entry.client_size} bytes)")
      IO.puts("    Valid: #{entry.valid?}")
      IO.puts("    Progress: #{entry.progress}%")
      IO.puts("    Done: #{entry.done?}")
    end)

    # NO activar el loader aquí - el hook ImageCropper manejará la imagen
    # El loader se activará cuando se reciba el evento cropped_image_ready

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  @impl true
  def handle_event("clear-result", _params, socket) do
    socket =
      socket
      |> assign(:result, nil)
      |> assign(:error, nil)
      |> assign(:processing, false)
      |> assign(:uploaded_files, [])

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_history", _params, socket) do
    {:noreply, assign(socket, :show_history, !socket.assigns.show_history)}
  end

  @impl true
  def handle_event("history_loaded", %{"tickets" => tickets}, socket) do
    {:noreply, assign(socket, :ticket_history, tickets)}
  end

  @impl true
  def handle_event("ask_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :ticket_to_delete, id)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :ticket_to_delete, nil)}
  end

  @impl true
  def handle_event("delete_ticket", %{"id" => id}, socket) do
    # Only proceed if we are confirming the deletion of the specific ticket
    # This prevents accidental deletions if the UI is stale or clicked directly
    if socket.assigns.ticket_to_delete == id do
      new_history =
        Enum.reject(socket.assigns.ticket_history, fn ticket -> ticket["id"] == id end)

      socket =
        socket
        |> assign(:ticket_history, new_history)
        |> assign(:ticket_to_delete, nil)
        |> push_event("delete_ticket_from_history", %{id: id})

      {:noreply, socket}
    else
      IO.puts(
        "⚠️ Attempted to delete ticket #{id} without confirmation (expected #{inspect(socket.assigns.ticket_to_delete)})"
      )

      # Do not delete, just clear the deleting state if mismatched
      {:noreply, assign(socket, :ticket_to_delete, nil)}
    end
  end

  @impl true
  def handle_event("start_processing", _params, socket) do
    IO.puts("🔄 Iniciando procesamiento - mostrando spinner")
    # Set processing state to show spinner
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
    IO.puts("🎨 Imagen recortada recibida:")
    IO.puts("  - Filename: #{filename}")
    IO.puts("  - Content-Type: #{content_type}")
    IO.puts("  - Size: #{(size / 1024) |> Float.round(2)}KB")

    # Processing is already true from start_processing event
    socket = assign(socket, :processing, true)

    # Decode base64
    binary_data = Base.decode64!(base64)

    # Process and upload to S3
    case process_and_upload_image(binary_data, filename) do
      {:ok, image_url, processed_binary} ->
        # Re-encode for OpenRouter (use already processed binary)
        base64_content = Base.encode64(processed_binary)

        uploaded_file = %{
          filename: filename,
          content_type: content_type,
          base64: base64_content,
          image_url: image_url
        }

        socket =
          socket
          |> update(:uploaded_files, &(&1 ++ [uploaded_file]))
          |> process_image(uploaded_file)

        {:noreply, socket}

      {:error, reason} ->
        IO.puts("⚠️ S3 upload failed, using cropped image directly: #{inspect(reason)}")

        uploaded_file = %{
          filename: filename,
          content_type: content_type,
          base64: base64,
          image_url: nil
        }

        socket =
          socket
          |> update(:uploaded_files, &(&1 ++ [uploaded_file]))
          |> process_image(uploaded_file)

        {:noreply, socket}
    end
  end

  def handle_progress(:image, entry, socket) do
    IO.puts("📤 Progress: #{entry.progress}% - #{entry.client_name}")

    if entry.done? do
      IO.puts("✅ Carga completa. Procesando archivo...")

      uploaded_file =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          # Read the file
          file_content = File.read!(path)

          # Process and upload to S3
          case process_and_upload_image(file_content, entry.client_name) do
            {:ok, image_url, processed_binary} ->
              # Use processed binary for OpenRouter
              base64_content = Base.encode64(processed_binary)

              {:ok,
               %{
                 filename: entry.client_name,
                 content_type: "image/webp",
                 base64: base64_content,
                 image_url: image_url
               }}

            {:error, _reason} ->
              # Fallback: use original image without S3 upload
              IO.puts("⚠️ S3 upload failed, using original image")
              base64_content = Base.encode64(file_content)

              {:ok,
               %{
                 filename: entry.client_name,
                 content_type: entry.client_type,
                 base64: base64_content,
                 image_url: nil
               }}
          end
        end)

      socket =
        socket
        |> update(:uploaded_files, &(&1 ++ [uploaded_file]))
        |> assign(:processing, true)
        |> process_image(uploaded_file)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Process image (detect ticket, crop, optimize) and upload to S3
  defp process_and_upload_image(binary_data, filename) do
    alias TicketSplitter.{ImageProcessor, Storage}

    with {:ok, processed_binary, content_type} <- ImageProcessor.process(binary_data),
         {:ok, url} <- Storage.upload_image(processed_binary, filename, content_type) do
      {:ok, url, processed_binary}
    else
      {:error, reason} ->
        IO.puts("❌ Error processing/uploading image: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_image(socket, uploaded_file) do
    # Log para debug
    IO.puts("🔄 Procesando imagen: #{uploaded_file.filename}")
    IO.puts("📁 Tipo de contenido: #{uploaded_file.content_type}")
    IO.puts("📊 Tamaño base64: #{String.length(uploaded_file.base64)} caracteres")

    # Aquí haremos la petición a OpenRouter
    case make_openrouter_request(uploaded_file) do
      {:ok, response} ->
        IO.puts("✅ Respuesta exitosa de OpenRouter")

        # Parsear el JSON de la respuesta
        case Parser.parse_response(response) do
          {:ok, products_json} ->
            # Guardar el ticket en la base de datos (with S3 image URL)
            case Tickets.create_ticket_from_json(products_json, uploaded_file.image_url) do
              {:ok, ticket} ->
                IO.puts("✅ Ticket guardado con ID: #{ticket.id}")

                # Save to localStorage history before navigating
                socket
                |> push_event("save_ticket_to_history", %{
                  ticket: %{
                    id: ticket.id,
                    merchant_name: ticket.merchant_name,
                    date: ticket.date
                  }
                })
                |> push_navigate(to: "/#{socket.assigns.locale}/tickets/#{ticket.id}")

              {:error, error} ->
                IO.puts("❌ Error guardando ticket: #{inspect(error)}")

                socket
                |> put_flash(:error, gettext("Error saving ticket"))
                |> assign(:processing, false)
                |> assign(:result, nil)
            end

          {:error, :not_a_receipt, error_message} ->
            IO.puts("⚠️ Imagen no es un ticket: #{error_message}")

            # Guardar la imagen en tickets-error para análisis
            save_error_image(uploaded_file)

            socket
            |> put_flash(
              :error,
              gettext("The uploaded image does not appear to be a valid receipt.")
            )
            |> assign(:processing, false)
            |> assign(:result, nil)

          {:error, error} ->
            IO.puts("❌ Error parseando JSON: #{inspect(error)}")

            socket
            |> put_flash(:error, gettext("Error parsing the response"))
            |> assign(:processing, false)
            |> assign(:result, nil)
        end

      {:error, :not_a_receipt, error_message} ->
        IO.puts("⚠️ Imagen no es un ticket (detectado en validación): #{error_message}")

        # Guardar la imagen en tickets-error para análisis
        save_error_image(uploaded_file)

        socket
        |> put_flash(:error, gettext("The uploaded image does not appear to be a valid receipt."))
        |> assign(:processing, false)
        |> assign(:result, nil)

      {:error, :parsing_failed} ->
        IO.puts("❌ Fallo en el parseo después de #{@max_retries} intentos")

        # Guardar la imagen en tickets-error para análisis
        save_error_image(uploaded_file)

        socket
        |> put_flash(
          :error,
          gettext("Could not extract ticket information. Please try with a clearer image.")
        )
        |> assign(:processing, false)
        |> assign(:result, nil)

      {:error, error} ->
        IO.puts("❌ Error en OpenRouter: #{inspect(error)}")

        socket
        |> put_flash(:error, gettext("Error processing the image"))
        |> assign(:processing, false)
        |> assign(:result, nil)
    end
  end

  # Guarda la imagen con error en la carpeta tickets-error para análisis posterior
  defp save_error_image(uploaded_file) do
    Task.start(fn ->
      # Decodificar la imagen
      binary_data = Base.decode64!(uploaded_file.base64)

      # Subir a la carpeta tickets-error
      case TicketSplitter.Storage.upload_error_image(
             binary_data,
             uploaded_file.filename,
             uploaded_file.content_type
           ) do
        {:ok, url} ->
          IO.puts("✅ Imagen con error guardada en: #{url}")

        {:error, reason} ->
          IO.puts("⚠️ No se pudo guardar la imagen con error: #{inspect(reason)}")
      end
    end)
  end

  defp make_openrouter_request(uploaded_file) do
    api_key = Application.get_env(:ticket_splitter, :openrouter_api_key)
    model = Application.get_env(:ticket_splitter, :openrouter_model)
    main_prompt = Prompt.main_prompt()
    validation_prompt = Prompt.validation_prompt()

    IO.puts(
      "🔑 API Key configurada: #{if api_key, do: "Sí (***#{String.slice(api_key, -4..-1)})", else: "No"}"
    )

    IO.puts("🤖 Usando modelo: #{model}")
    IO.puts("💬 Prompt: #{String.slice(main_prompt, 0, 50)}...")

    unless api_key do
      {:error, "API key no configurada"}
    else
      # Iniciar bucle de validación
      Validator.validate_with_retry(
        uploaded_file,
        api_key,
        model,
        main_prompt,
        validation_prompt,
        @max_retries
      )
    end
  end
end
