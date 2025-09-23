defmodule TicketSplitterWeb.PageController do
  use TicketSplitterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
