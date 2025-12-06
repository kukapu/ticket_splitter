defmodule TicketSplitterWeb.HomeLive do
  use TicketSplitterWeb, :live_view

  alias TicketSplitter.Tickets

  # Modelos de OpenRouter en orden de preferencia (fallback)
  # Si el primer modelo falla, se intenta con el siguiente
  @openrouter_models [
    "google/gemini-2.5-flash-lite-preview-09-2025",
    "qwen/qwen-vl-plus",
    "amazon/nova-2-lite-v1:free",
    "x-ai/grok-4.1-fast:free"
  ]

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
      |> assign(:page_title, SEO.page_title(gettext("Split your expenses easily")))
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
        auto_upload: true,
        progress: &handle_progress/3
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

    # Activar el loader inmediatamente cuando se selecciona una imagen
    socket =
      if length(socket.assigns.uploads.image.entries) > 0 do
        assign(socket, :processing, true)
      else
        socket
      end

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

  def handle_progress(:image, entry, socket) do
    IO.puts("📤 Progress: #{entry.progress}% - #{entry.client_name}")

    if entry.done? do
      IO.puts("✅ Carga completa. Procesando archivo...")

      uploaded_file =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          # Leer el archivo y codificarlo en base64
          file_content = File.read!(path)
          base64_content = Base.encode64(file_content)

          {:ok,
           %{
             filename: entry.client_name,
             content_type: entry.client_type,
             base64: base64_content
           }}
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
            # Guardar el ticket en la base de datos
            case Tickets.create_ticket_from_json(products_json, uploaded_file.filename) do
              {:ok, ticket} ->
                IO.puts("✅ Ticket guardado con ID: #{ticket.id}")
                # Redirigir a la página del ticket
                push_navigate(socket, to: "/tickets/#{ticket.id}")

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
    prompt = read_prompt_from_file()

    IO.puts(
      "🔑 API Key configurada: #{if api_key, do: "Sí (***#{String.slice(api_key, -4..-1)})", else: "No"}"
    )

    IO.puts("🤖 Modelos disponibles (en orden de preferencia): #{inspect(@openrouter_models)}")
    IO.puts("💬 Prompt: #{String.slice(prompt, 0, 50)}...")

    unless api_key do
      {:error, "API key no configurada"}
    else
      # Intentar con cada modelo en orden hasta que uno funcione
      try_models_in_order(@openrouter_models, uploaded_file, api_key, prompt)
    end
  end

  # Intenta con cada modelo en orden hasta que uno funcione
  defp try_models_in_order([], _uploaded_file, _api_key, _prompt) do
    {:error, "Todos los modelos fallaron"}
  end

  defp try_models_in_order([model | rest], uploaded_file, api_key, prompt) do
    IO.puts("\n🤖 Intentando con modelo: #{model}")

    case call_openrouter_api(model, uploaded_file, api_key, prompt) do
      {:ok, body} ->
        IO.puts("✅ Modelo #{model} respondió exitosamente")
        {:ok, body}

      {:error, reason} ->
        IO.puts("⚠️ Modelo #{model} falló: #{inspect(reason)}")

        if rest == [] do
          IO.puts("❌ No quedan más modelos para intentar")
          {:error, reason}
        else
          IO.puts("🔄 Intentando con el siguiente modelo...")
          try_models_in_order(rest, uploaded_file, api_key, prompt)
        end
    end
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

    # Usar Task con timeout para garantizar máximo 6 segundos por modelo
    task =
      Task.async(fn ->
        Req.post("https://openrouter.ai/api/v1/chat/completions",
          json: payload,
          headers: headers
        )
      end)

    case Task.yield(task, 12_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, %{status: 200, body: body}}} ->
        IO.puts("✅ Respuesta HTTP 200 recibida")
        IO.puts("📦 Body completo de OpenRouter:")
        IO.inspect(body, pretty: true, limit: :infinity)
        {:ok, body}

      {:ok, {:ok, %{status: status, body: body}}} ->
        IO.puts("⚠️ Respuesta HTTP #{status}: #{inspect(body)}")
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:ok, {:error, error}} ->
        IO.puts("❌ Error de red: #{inspect(error)}")
        {:error, error}

      nil ->
        IO.puts("⏱️ Timeout después de 6 segundos para modelo #{model}")
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

  defp error_to_string(:too_large), do: gettext("File is too large (max. 10MB)")
  defp error_to_string(:not_accepted), do: gettext("Unsupported file format")
  defp error_to_string(:too_many_files), do: gettext("Only one file allowed at a time")
  defp error_to_string(error), do: gettext("Error: %{error}", error: inspect(error))
end
