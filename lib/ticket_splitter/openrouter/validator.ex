defmodule TicketSplitter.OpenRouter.Validator do
  @moduledoc """
  Cross-validation logic for OpenRouter responses.
  Validates totals across multiple API calls with retry mechanism.
  """

  alias TicketSplitter.OpenRouter.{Client, Parser}

  @default_max_retries 3

  @doc """
  Validates the response with cross-validation using parallel API calls.
  Makes two parallel requests: one for main analysis and one for total validation.
  Retries up to max_retries times if totals don't match.
  """
  def validate_with_retry(uploaded_file, api_key, model, main_prompt, validation_prompt, max_retries \\ @default_max_retries) do
    IO.puts("\n🔄 Intento ##{1} de #{max_retries}...")

    # Lanzar tareas en paralelo
    main_task =
      Task.async(fn ->
        IO.puts("🚀 Lanzando petición MAIN...")
        Client.send_request(model, uploaded_file, api_key, main_prompt)
      end)

    val_task =
      Task.async(fn ->
        IO.puts("🚀 Lanzando petición VALIDATION...")
        Client.send_request(model, uploaded_file, api_key, validation_prompt)
      end)

    # Esperar resultados (Timeout generoso de 30s)
    result_main = Task.await(main_task, 30_000)
    result_val = Task.await(val_task, 30_000)

    case {result_main, result_val} do
      {{:ok, body_main}, {:ok, body_val}} ->
        IO.puts("📥 Ambas peticiones respondieron. Verificando validez y totales...")

        # Primero verificar si la imagen es un ticket válido
        case Parser.check_if_receipt(body_main) do
          {:error, :not_a_receipt, error_message} ->
            IO.puts("⚠️ Imagen no es un ticket válido, deteniendo procesamiento")
            {:error, :not_a_receipt, error_message}

          :ok ->
            # Extraer totales
            total_main = Parser.extract_total_from_response(body_main)
            total_val = Parser.extract_total_from_response(body_val)

            IO.puts("💰 Total Main: #{inspect(total_main)}")
            IO.puts("💰 Total Validation: #{inspect(total_val)}")

            if totals_match?(total_main, total_val) do
              IO.puts("✅ ¡TOTALES COINCIDEN! Validación exitosa.")
              {:ok, body_main}
            else
              IO.puts("⚠️ DISCREPANCIA EN TOTALES.")

              if max_retries > 1 do
                IO.puts("🔄 Reintentando proceso...")
                validate_with_retry(uploaded_file, api_key, model, main_prompt, validation_prompt, max_retries - 1)
              else
                IO.puts("❌ Se agotaron los #{max_retries} intentos. Fallo definitivo.")
                {:error, :parsing_failed}
              end
            end
        end

      _ ->
        IO.puts("⚠️ Error en alguna de las peticiones HTTP.")

        if max_retries > 1 do
          IO.puts("🔄 Reintentando proceso...")
          validate_with_retry(uploaded_file, api_key, model, main_prompt, validation_prompt, max_retries - 1)
        else
          IO.puts("❌ Se agotaron los #{max_retries} intentos. Fallo definitivo.")
          {:error, :parsing_failed}
        end
    end
  end

  @doc """
  Compares two total values with a small tolerance for rounding errors.
  Returns true if the difference is less than 0.05.
  """
  def totals_match?(nil, _), do: false
  def totals_match?(_, nil), do: false

  def totals_match?(val1, val2) do
    # Convertir a Decimal para comparación segura
    d1 = Decimal.new(to_string(val1))
    d2 = Decimal.new(to_string(val2))

    # Permitir diferencia pequeña por errores de redondeo (0.05)
    diff = Decimal.sub(d1, d2) |> Decimal.abs()
    Decimal.compare(diff, Decimal.new("0.05")) in [:lt, :eq]
  rescue
    _ -> false
  end
end
