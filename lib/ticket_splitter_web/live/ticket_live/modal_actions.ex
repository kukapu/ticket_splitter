defmodule TicketSplitterWeb.TicketLive.ModalActions do
  @moduledoc """
  Módulo que contiene funciones para gestionar acciones simples de modales.
  """

  @doc """
  Construye assigns para cerrar un modal booleano.
  """
  def close_modal_assigns(modal_name) do
    [{modal_name, false}]
  end

  @doc """
  Construye assigns para abrir un modal booleano.
  """
  def open_modal_assigns(modal_name) do
    [{modal_name, true}]
  end

  @doc """
  Construye assigns para toggle un modal booleano.
  """
  def toggle_modal_assigns(modal_name, current_state) do
    [{modal_name, !current_state}]
  end

  @doc """
  Construye assigns para abrir/cerrar el editor de porcentajes.
  """
  def editing_percentages_assigns(product_id) do
    [editing_percentages_product_id: product_id]
  end

  @doc """
  Construye assigns para cerrar el editor de porcentajes.
  """
  def close_editing_percentages_assigns() do
    [editing_percentages_product_id: nil]
  end
end
