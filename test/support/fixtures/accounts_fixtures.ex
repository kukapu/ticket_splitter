defmodule TicketSplitter.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TicketSplitter.Accounts` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        id: "some id",
        name: "some name"
      })
      |> TicketSplitter.Accounts.create_user()

    user
  end
end
