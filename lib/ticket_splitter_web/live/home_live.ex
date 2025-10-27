defmodule TicketSplitterWeb.HomeLive do
  use TicketSplitterWeb, :live_view

  alias TicketSplitter.Tickets

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:uploaded_files, [])
      |> assign(:processing, false)
      |> assign(:result, nil)
      |> assign(:error, nil)
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
    socket = if length(socket.assigns.uploads.image.entries) > 0 do
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
  def handle_info({ref, result}, socket) when is_reference(ref) do
    # Limpiar el task completado
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, ticket} ->
        IO.puts("✅ Ticket guardado con ID: #{ticket.id}")
        {:noreply, push_navigate(socket, to: "/tickets/#{ticket.id}")}

      {:error, error} ->
        IO.puts("❌ Error procesando imagen: #{inspect(error)}")
        socket =
          socket
          |> assign(:error, "Error procesando la imagen: #{error}")
          |> assign(:processing, false)
          |> assign(:result, nil)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Task terminado (normal o con error)
    {:noreply, socket}
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

          {:ok, %{
            filename: entry.client_name,
            content_type: entry.client_type,
            base64: base64_content
          }}
        end)

      # Iniciar tarea asíncrona para procesar la imagen
      task = Task.async(fn -> process_image_async(uploaded_file) end)

      socket =
        socket
        |> update(:uploaded_files, &(&1 ++ [uploaded_file]))
        |> assign(:processing, true)
        |> assign(:processing_task, task)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp process_image_async(uploaded_file) do
    # Log para debug
    IO.puts("🔄 Procesando imagen: #{uploaded_file.filename}")
    IO.puts("📁 Tipo de contenido: #{uploaded_file.content_type}")
    IO.puts("📊 Tamaño base64: #{String.length(uploaded_file.base64)} caracteres")

    # Aquí haremos la petición a OpenRouter
    with {:ok, response} <- make_openrouter_request(uploaded_file),
         {:ok, products_json} <- parse_openrouter_response(response),
         {:ok, ticket} <- Tickets.create_ticket_from_json(products_json, uploaded_file.filename) do
      IO.puts("✅ Ticket guardado con ID: #{ticket.id}")
      {:ok, ticket}
    else
      {:error, error} ->
        IO.puts("❌ Error: #{inspect(error)}")
        {:error, inspect(error)}
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
          {:ok, json}

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
    # Configuración que deberás personalizar
    api_key = Application.get_env(:ticket_splitter, :openrouter_api_key)
    model = Application.get_env(:ticket_splitter, :openrouter_model, "openai/gpt-4o")
    prompt = read_prompt_from_file()

    IO.puts("🔑 API Key configurada: #{if api_key, do: "Sí (***#{String.slice(api_key, -4..-1)})", else: "No"}")
    IO.puts("🤖 Modelo: #{model}")
    IO.puts("💬 Prompt: #{String.slice(prompt, 0, 50)}...")

    unless api_key do
      {:error, "API key no configurada"}
    else
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

      IO.puts("🌐 Enviando petición a OpenRouter...")

      case Req.post("https://openrouter.ai/api/v1/chat/completions",
             json: payload,
             headers: headers,
             receive_timeout: 60_000
           ) do
        {:ok, %{status: 200, body: body}} ->
          IO.puts("✅ Respuesta HTTP 200 recibida")
          IO.puts("📦 Body completo de OpenRouter:")
          IO.inspect(body, pretty: true, limit: :infinity)
          {:ok, body}

        {:ok, %{status: status, body: body}} ->
          IO.puts("⚠️ Respuesta HTTP #{status}: #{inspect(body)}")
          {:error, "HTTP #{status}: #{inspect(body)}"}

        {:error, error} ->
          IO.puts("❌ Error de red: #{inspect(error)}")
          {:error, error}
      end
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

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 1)} KB"
      true -> "#{bytes} bytes"
    end
  end

  defp format_file_size(_), do: "0 bytes"

  defp error_to_string(:too_large), do: "El archivo es demasiado grande (máx. 10MB)"
  defp error_to_string(:not_accepted), do: "Formato de archivo no soportado"
  defp error_to_string(:too_many_files), do: "Solo se permite un archivo a la vez"
  defp error_to_string(error), do: "Error: #{inspect(error)}"
end
