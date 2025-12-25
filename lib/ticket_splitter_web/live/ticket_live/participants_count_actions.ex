defmodule TicketSplitterWeb.TicketLive.ParticipantsCountActions do
  @moduledoc """
  Módulo que contiene funciones para gestionar el conteo de participantes.
  """

  @doc """
  Calcula el nuevo conteo al incrementar.
  """
  def calculate_increment(current_count) do
    current_count + 1
  end

  @doc """
  Calcula el nuevo conteo al decrementar (respetando el mínimo).
  """
  def calculate_decrement(current_count, min_count) do
    max(current_count - 1, min_count)
  end

  @doc """
  Parsea y valida un valor de conteo de participantes.
  """
  def parse_and_validate_value(value, _min_count) do
    case Integer.parse(value) do
      {num, _} when num > 0 ->
        {:ok, num}

      _ ->
        :error
    end
  end
end
