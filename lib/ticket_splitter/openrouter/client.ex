defmodule TicketSplitter.OpenRouter.Client do
  @moduledoc """
  HTTP client for OpenRouter API interactions.
  Handles API requests with proper headers and payload structure.
  """

  @base_url "https://openrouter.ai/api/v1/chat/completions"

  @doc """
  Sends a request to OpenRouter API with the given model, uploaded file, API key, and prompt.
  Returns {:ok, response_body} or {:error, reason}.
  """
  def send_request(model, uploaded_file, api_key, prompt) do
    payload = build_payload(model, uploaded_file, prompt)
    headers = build_headers(api_key)

    IO.puts("🌐 Enviando petición a OpenRouter con modelo #{model}...")

    task =
      Task.async(fn ->
        Req.post(@base_url,
          json: payload,
          headers: headers,
          receive_timeout: 60_000
        )
      end)

    case Task.yield(task, 60_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, %{status: 200, body: body}}} ->
        IO.puts("✅ Respuesta HTTP 200 recibida")
        {:ok, body}

      {:ok, {:ok, %{status: status, body: body}}} ->
        IO.puts("⚠️ Respuesta HTTP #{status}: #{inspect(body)}")
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:ok, {:error, error}} ->
        IO.puts("❌ Error de red: #{inspect(error)}")
        {:error, error}

      nil ->
        IO.puts("⏱️ Timeout después de 60 segundos para modelo #{model}")
        {:error, :timeout}
    end
  end

  @doc """
  Returns the base URL for OpenRouter API.
  """
  def base_url, do: @base_url

  # Private functions

  defp build_payload(model, uploaded_file, prompt) do
    %{
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
  end

  defp build_headers(api_key) do
    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", "https://ticket-splitter.com"},
      {"X-Title", "Ticket Splitter"}
    ]
  end
end
