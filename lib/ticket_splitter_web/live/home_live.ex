defmodule TicketSplitterWeb.HomeLive do
  use TicketSplitterWeb, :live_view

  alias TicketSplitter.Tickets

  # Modelo único para análisis
  @openrouter_model "google/gemini-2.5-flash-lite-preview-09-2025"
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
        case parse_openrouter_response(response) do
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
                |> assign(:error, "Error guardando el ticket: #{inspect(error)}")
                |> assign(:processing, false)
                |> assign(:result, nil)
            end

          {:error, :not_a_receipt, error_message} ->
            IO.puts("⚠️ Imagen no es un ticket: #{error_message}")

            socket
            |> put_flash(:error, error_message)
            |> assign(:processing, false)
            |> assign(:result, nil)

          {:error, error} ->
            IO.puts("❌ Error parseando JSON: #{inspect(error)}")

            socket
            |> assign(:error, "Error parseando la respuesta: #{error}")
            |> assign(:processing, false)
            |> assign(:result, nil)
        end

      {:error, error} ->
        IO.puts("❌ Error en OpenRouter: #{inspect(error)}")

        socket
        |> assign(:error, "Error procesando la imagen: #{inspect(error)}")
        |> assign(:processing, false)
        |> assign(:result, nil)
    end
  end

  defp parse_openrouter_response(response) do
    IO.puts("\n🔍 Parseando respuesta de OpenRouter...")

    with {:ok, choices} <- Map.fetch(response, "choices"),
         [first_choice | _] <- choices,
         {:ok, message} <- Map.fetch(first_choice, "message"),
         {:ok, content} <- Map.fetch(message, "content") do
      IO.puts("📝 Content recibido (primeros 500 chars):")
      IO.puts(String.slice(content, 0, 500))

      # Limpiar markdown code blocks (```json ... ```)
      cleaned_content =
        content
        |> String.replace(~r/^```json\s*/m, "")
        |> String.replace(~r/```\s*$/m, "")
        |> String.trim()

      IO.puts("\n🧹 Content limpiado (primeros 500 chars):")
      IO.puts(String.slice(cleaned_content, 0, 500))

      # El content debería ser un JSON string
      case Jason.decode(cleaned_content) do
        {:ok, json} ->
          IO.puts("✅ JSON parseado exitosamente:")
          IO.inspect(json, pretty: true, limit: :infinity)

          # Verificar si el LLM detectó que la imagen no es un ticket
          case json do
            %{"is_receipt" => false, "error_message" => error_message} ->
              IO.puts("⚠️ La imagen no es un ticket válido: #{error_message}")
              {:error, :not_a_receipt, error_message}

            %{"is_receipt" => false} ->
              IO.puts("⚠️ La imagen no es un ticket válido")
              {:error, :not_a_receipt, "La imagen no parece ser un ticket válido."}

            _ ->
              {:ok, json}
          end

        {:error, error} ->
          IO.puts("❌ Error al parsear JSON:")
          IO.inspect(error)
          {:error, "El contenido no es JSON válido"}
      end
    else
      error ->
        IO.puts("❌ Error en el formato de respuesta:")
        IO.inspect(error)
        {:error, "Formato de respuesta inválido"}
    end
  end

  defp make_openrouter_request(uploaded_file) do
    api_key = Application.get_env(:ticket_splitter, :openrouter_api_key)
    main_prompt = read_prompt_from_file()

    # Prompt de validación para obtener solo el total
    validation_prompt = """
    Analiza la imagen y devuelve ÚNICAMENTE un objeto JSON con el total a pagar del ticket.
    Formato: {"total_amount": <numero>}.
    Si hay multiples tickets, suma los totales.
    Ejemplo: {"total_amount": 24.50}
    NO incluyas texto extra, solo el JSON.
    """

    IO.puts(
      "🔑 API Key configurada: #{if api_key, do: "Sí (***#{String.slice(api_key, -4..-1)})", else: "No"}"
    )

    IO.puts("🤖 Usando modelo único: #{@openrouter_model}")
    IO.puts("💬 Prompt: #{String.slice(main_prompt, 0, 50)}...")

    unless api_key do
      {:error, "API key no configurada"}
    else
      # Iniciar bucle de validación
      process_with_validation_loop(
        uploaded_file,
        api_key,
        @openrouter_model,
        main_prompt,
        validation_prompt,
        @max_retries
      )
    end
  end

  # Bucle de reintentos con validación paralela
  defp process_with_validation_loop(
         uploaded_file,
         api_key,
         model,
         main_prompt,
         val_prompt,
         attempts_left
       ) do
    IO.puts("\n🔄 Intento ##{4 - attempts_left} de #{@max_retries}...")

    # Lanzar tareas en paralelo
    main_task =
      Task.async(fn ->
        IO.puts("🚀 Lanzando petición MAIN...")
        call_openrouter_api(model, uploaded_file, api_key, main_prompt)
      end)

    val_task =
      Task.async(fn ->
        IO.puts("🚀 Lanzando petición VALIDATION...")
        call_openrouter_api(model, uploaded_file, api_key, val_prompt)
      end)

    # Esperar resultados (Timeout generoso de 30s)
    result_main = Task.await(main_task, 30_000)
    result_val = Task.await(val_task, 30_000)

    case {result_main, result_val} do
      {{:ok, body_main}, {:ok, body_val}} ->
        IO.puts("📥 Ambas peticiones respondieron. Verificando totales...")

        # Extraer totales
        total_main = extract_total_from_response(body_main)
        total_val = extract_total_from_response(body_val)

        IO.puts("💰 Total Main: #{inspect(total_main)}")
        IO.puts("💰 Total Validation: #{inspect(total_val)}")

        if totals_match?(total_main, total_val) do
          IO.puts("✅ ¡TOTALES COINCIDEN! Validación exitosa.")
          {:ok, body_main}
        else
          IO.puts("⚠️ DISCREPANCIA EN TOTALES.")

          retry_or_fail(
            "Totales no coinciden",
            uploaded_file,
            api_key,
            model,
            main_prompt,
            val_prompt,
            attempts_left
          )
        end

      _ ->
        IO.puts("⚠️ Error en alguna de las peticiones HTTP.")

        retry_or_fail(
          "Error en petición API",
          uploaded_file,
          api_key,
          model,
          main_prompt,
          val_prompt,
          attempts_left
        )
    end
  end

  defp retry_or_fail(
         reason,
         uploaded_file,
         api_key,
         model,
         main_prompt,
         val_prompt,
         attempts_left
       ) do
    if attempts_left > 1 do
      IO.puts("🔄 Reintentando proceso...")

      process_with_validation_loop(
        uploaded_file,
        api_key,
        model,
        main_prompt,
        val_prompt,
        attempts_left - 1
      )
    else
      IO.puts("❌ Se agotaron los intentos. Fallo definitivo.")
      {:error, reason}
    end
  end

  # Helper para comparar totales con tolerancia pequeña
  defp totals_match?(nil, _), do: false
  defp totals_match?(_, nil), do: false

  defp totals_match?(val1, val2) do
    # Convertir a Decimal para comparación segura
    d1 = Decimal.new(to_string(val1))
    d2 = Decimal.new(to_string(val2))

    # Permitir diferencia pequeña por errores de redondeo (0.05)
    diff = Decimal.sub(d1, d2) |> Decimal.abs()
    Decimal.compare(diff, Decimal.new("0.05")) in [:lt, :eq]
  rescue
    _ -> false
  end

  # Extrae el total_amount de un body de OpenRouter
  defp extract_total_from_response(body) do
    with {:ok, content} <- extract_content(body),
         {:ok, json} <- Jason.decode(sanitize_json_content(content)) do
      case json do
        %{"total_amount" => amount} when is_number(amount) ->
          amount

        %{"total_amount" => amount} when is_binary(amount) ->
          case Float.parse(amount) do
            {val, _} -> val
            _ -> nil
          end

        _ ->
          nil
      end
    else
      _ -> nil
    end
  end

  defp extract_content(response) do
    with {:ok, choices} <- Map.fetch(response, "choices"),
         [first_choice | _] <- choices,
         {:ok, message} <- Map.fetch(first_choice, "message"),
         {:ok, content} <- Map.fetch(message, "content") do
      {:ok, content}
    else
      _ -> :error
    end
  end

  defp sanitize_json_content(content) do
    content
    |> String.replace(~r/^```json\s*/m, "")
    |> String.replace(~r/```\s*$/m, "")
    |> String.trim()
  end

  # Hace la llamada real a la API de OpenRouter
  defp call_openrouter_api(model, uploaded_file, api_key, prompt) do
    payload = %{
      "model" => model,
      "messages" => [
        %{
          "role" => "user",
          "content" => [
            %{
              "type" => "text",
              "text" => prompt
            },
            %{
              "type" => "image_url",
              "image_url" => %{
                "url" => "data:#{uploaded_file.content_type};base64,#{uploaded_file.base64}"
              }
            }
          ]
        }
      ],
      "max_tokens" => 10000
    }

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", "https://ticket-splitter.com"},
      {"X-Title", "Ticket Splitter"}
    ]

    IO.puts("🌐 Enviando petición a OpenRouter con modelo #{model}...")

    # Usar Task con timeout para garantizar máximo 15 segundos por modelo
    # NOTA: Como la llamada ya está envuelta en Task.async desde process_with_validation_loop,
    # esta espera es interna de la tarea.
    task =
      Task.async(fn ->
        Req.post("https://openrouter.ai/api/v1/chat/completions",
          json: payload,
          headers: headers,
          receive_timeout: 25_000
        )
      end)

    case Task.yield(task, 25_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, %{status: 200, body: body}}} ->
        IO.puts("✅ Respuesta HTTP 200 recibida")
        # IO.puts("📦 Body completo de OpenRouter:")
        # IO.inspect(body, pretty: true, limit: :infinity)
        {:ok, body}

      {:ok, {:ok, %{status: status, body: body}}} ->
        IO.puts("⚠️ Respuesta HTTP #{status}: #{inspect(body)}")
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:ok, {:error, error}} ->
        IO.puts("❌ Error de red: #{inspect(error)}")
        {:error, error}

      nil ->
        IO.puts("⏱️ Timeout después de 25 segundos para modelo #{model}")
        {:error, :timeout}
    end
  end

  # Helper functions
  defp read_prompt_from_file do
    prompt_path = Application.app_dir(:ticket_splitter, "priv/openrouter_prompt.txt")

    case File.read(prompt_path) do
      {:ok, content} -> String.trim(content)
      {:error, _} -> "Analiza esta imagen y describe lo que ves."
    end
  end
end
