defmodule TicketSplitterWeb.HomeLive do
  use TicketSplitterWeb, :live_view

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
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
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
      |> assign(:uploaded_files, [])

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
        socket
        |> assign(:result, response)
        |> assign(:processing, false)
        |> assign(:error, nil)

      {:error, error} ->
        IO.puts("❌ Error en OpenRouter: #{inspect(error)}")
        socket
        |> assign(:error, "Error procesando la imagen: #{inspect(error)}")
        |> assign(:processing, false)
        |> assign(:result, nil)
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
        "max_tokens" => 1000
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
             receive_timeout: 30_000
           ) do
        {:ok, %{status: 200, body: body}} ->
          IO.puts("✅ Respuesta HTTP 200 recibida")
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
