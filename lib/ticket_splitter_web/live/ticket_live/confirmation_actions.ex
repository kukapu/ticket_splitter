defmodule TicketSplitterWeb.TicketLive.ConfirmationActions do
  @moduledoc """
  Módulo que contiene funciones para gestionar confirmaciones de share/unshare.
  """

  @doc """
  Construye assigns para mostrar confirmación de unshare.
  """
  def show_unshare_confirmation_assigns(params) do
    [
      show_unshare_confirmation: true,
      pending_share_action: params
    ]
  end

  @doc """
  Construye assigns para ocultar confirmación de unshare.
  """
  def hide_unshare_confirmation_assigns() do
    [
      show_unshare_confirmation: false,
      pending_share_action: nil
    ]
  end

  @doc """
  Construye assigns para mostrar confirmación de share.
  """
  def show_share_confirmation_assigns(params) do
    [
      show_share_confirmation: true,
      pending_share_action: params
    ]
  end

  @doc """
  Construye assigns para ocultar confirmación de share.
  """
  def hide_share_confirmation_assigns() do
    [
      show_share_confirmation: false,
      pending_share_action: nil
    ]
  end
end
