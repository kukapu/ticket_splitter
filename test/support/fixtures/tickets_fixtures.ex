defmodule TicketSplitter.TicketsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TicketSplitter.Tickets` context.
  """

  alias TicketSplitter.Repo
  alias TicketSplitter.Tickets.{Ticket, Product, ParticipantAssignment, ParticipantConfig}

  @doc """
  Generate a ticket.
  """
  def ticket_fixture(attrs \\ %{}) do
    {:ok, ticket} =
      attrs
      |> Enum.into(%{
        merchant_name: "Test Merchant",
        total: Decimal.new("100.00"),
        date: ~D[2024-01-15],
        image_url: "https://example.com/ticket.jpg",
        total_participants: 1
      })
      |> TicketSplitter.Tickets.create_ticket()

    ticket
  end

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    # Create a ticket if not provided
    ticket =
      case attrs[:ticket_id] do
        nil ->
          ticket_fixture()

        ticket_id when is_binary(ticket_id) ->
          Repo.get!(Ticket, ticket_id)
      end

    {:ok, product} =
      attrs
      |> Enum.into(%{
        ticket_id: ticket.id,
        name: "Test Product",
        total_price: Decimal.new("10.00"),
        unit_price: Decimal.new("1.00"),
        units: 10,
        is_common: false,
        common_units: Decimal.new("0")
      })
      |> TicketSplitter.Tickets.create_product()

    product
  end

  @doc """
  Generate a participant assignment.
  """
  def participant_assignment_fixture(attrs \\ %{}) do
    # Create a product if not provided
    product =
      case attrs[:product_id] do
        nil ->
          product_fixture()

        product_id when is_binary(product_id) ->
          Repo.get!(Product, product_id)
      end

    %ParticipantAssignment{}
    |> ParticipantAssignment.changeset(
      attrs
      |> Enum.into(%{
        product_id: product.id,
        participant_name: "Test Participant",
        units_assigned: Decimal.new("1"),
        percentage: Decimal.new("100"),
        assigned_color: "#FF0000"
      })
    )
    |> Repo.insert!()
  end

  @doc """
  Generate a ticket with products.
  """
  def ticket_with_products_fixture(attrs \\ %{}) do
    ticket =
      attrs
      |> Enum.into(%{
        merchant_name: "Test Merchant",
        total: Decimal.new("100.00"),
        date: ~D[2024-01-15],
        image_url: "https://example.com/ticket.jpg",
        total_participants: 1
      })
      |> TicketSplitter.Tickets.create_ticket()
      |> case do
        {:ok, t} -> t
        {:error, _} -> ticket_fixture()
      end

    products =
      Enum.map(1..3, fn i ->
        product_fixture(%{
          ticket_id: ticket.id,
          name: "Product #{i}",
          total_price: Decimal.new("#{i * 10}.00"),
          unit_price: Decimal.new("#{i}.00"),
          units: i * 10
        })
      end)

    {ticket, products}
  end

  @doc """
  Generate a participant config.
  """
  def participant_config_fixture(attrs \\ %{}) do
    # Create a ticket if not provided
    ticket =
      case attrs[:ticket_id] do
        nil ->
          ticket_fixture()

        ticket_id when is_binary(ticket_id) ->
          Repo.get!(Ticket, ticket_id)
      end

    %ParticipantConfig{}
    |> ParticipantConfig.changeset(
      attrs
      |> Enum.into(%{
        ticket_id: ticket.id,
        participant_name: "Test Participant",
        multiplier: 1
      })
    )
    |> Repo.insert!()
  end
end
