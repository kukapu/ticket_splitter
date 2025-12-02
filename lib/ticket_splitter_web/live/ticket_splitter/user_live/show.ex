defmodule TicketSplitterWeb.TicketSplitter.UserLive.Show do
  use TicketSplitterWeb, :live_view

  alias TicketSplitter.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        User {@user.id}
        <:subtitle>This is a user record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/ticket_splitter/users"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            variant="primary"
            navigate={~p"/ticket_splitter/users/#{@user}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Edit user
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@user.name}</:item>
        <:item title="Id">{@user.id}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show User")
     |> assign(:user, Accounts.get_user!(id))}
  end
end
