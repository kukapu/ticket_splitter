defmodule TicketSplitterWeb.TicketLive.SliderInfoActions do
  @moduledoc """
  Módulo que contiene funciones para manejar eventos de sliders vía handle_info.
  """

  @doc """
  Construye assigns cuando un slider es bloqueado.
  """
  def slider_locked_assigns(locked_sliders, group_id, locked_by) do
    [locked_sliders: Map.put(locked_sliders, group_id, locked_by)]
  end

  @doc """
  Construye assigns cuando un slider es desbloqueado.
  """
  def slider_unlocked_assigns(locked_sliders, group_id) do
    [locked_sliders: Map.delete(locked_sliders, group_id)]
  end
end
