defmodule TicketSplitter.OpenRouter.Parser do
  @moduledoc """
  Parses OpenRouter JSON responses.
  Extracts content, validates structure, and handles receipt detection.
  """

  @doc """
  Parses the full OpenRouter response and extracts the products JSON.
  Returns {:ok, products_json} or {:error, reason}.
  """
  def parse_response(response) do
    IO.puts("\n🔍 Parseando respuesta de OpenRouter...")

    with {:ok, choices} <- Map.fetch(response, "choices"),
         [first_choice | _] <- choices,
         {:ok, message} <- Map.fetch(first_choice, "message"),
         {:ok, content} <- Map.fetch(message, "content") do
      IO.puts("📝 Content recibido (primeros 500 chars):")
      IO.puts(String.slice(content, 0, 500))

      # Limpiar markdown code blocks (```json ... ```)
      cleaned_content = sanitize_json_content(content)

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
              {:error, :not_a_receipt,
               "The uploaded image does not appear to be a valid receipt."}

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

  @doc """
  Extracts the content from an OpenRouter response body.
  Returns {:ok, content} or :error.
  """
  def extract_content(response) do
    with {:ok, choices} <- Map.fetch(response, "choices"),
         [first_choice | _] <- choices,
         {:ok, message} <- Map.fetch(first_choice, "message"),
         {:ok, content} <- Map.fetch(message, "content") do
      {:ok, content}
    else
      _ -> :error
    end
  end

  @doc """
  Sanitizes JSON content by removing markdown code blocks.
  """
  def sanitize_json_content(content) do
    content
    |> String.replace(~r/^```json\s*/m, "")
    |> String.replace(~r/```\s*$/m, "")
    |> String.trim()
  end

  @doc """
  Extracts the total_amount from an OpenRouter response body.
  Returns the amount as a number or nil if not found.
  """
  def extract_total_from_response(body) do
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

  @doc """
  Checks if the response indicates that the image is a valid receipt.
  Returns :ok, {:error, :not_a_receipt, error_message}, or {:error, :not_a_receipt, default_message}.
  """
  def check_if_receipt(response) do
    with {:ok, content} <- extract_content(response),
         {:ok, json} <- Jason.decode(sanitize_json_content(content)) do
      case json do
        %{"is_receipt" => false, "error_message" => error_message} ->
          {:error, :not_a_receipt, error_message}

        %{"is_receipt" => false} ->
          {:error, :not_a_receipt,
           "The uploaded image does not appear to be a valid receipt."}

        _ ->
          :ok
      end
    else
      _ -> :ok
    end
  end
end
