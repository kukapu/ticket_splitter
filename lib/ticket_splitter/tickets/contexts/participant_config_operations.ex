defmodule TicketSplitter.Tickets.Contexts.ParticipantConfigOperations do
  @moduledoc """
  Operations for ParticipantConfig CRUD and multiplier-related calculations.
  """

  import Ecto.Query, warn: false
  alias TicketSplitter.Repo
  alias TicketSplitter.Tickets.{ParticipantConfig, TicketCalculator}

  @doc """
  Gets a participant's config for a ticket.
  Returns nil if no config exists.
  """
  def get_participant_config(ticket_id, participant_name) do
    participant_name = String.trim(participant_name)

    ParticipantConfig
    |> where([pc], pc.ticket_id == ^ticket_id and pc.participant_name == ^participant_name)
    |> Repo.one()
  end

  @doc """
  Gets or creates a participant config for a ticket.
  """
  def get_or_create_participant_config(ticket_id, participant_name) do
    participant_name = String.trim(participant_name)

    case get_participant_config(ticket_id, participant_name) do
      nil ->
        %ParticipantConfig{}
        |> ParticipantConfig.changeset(%{
          ticket_id: ticket_id,
          participant_name: participant_name,
          multiplier: 1
        })
        |> Repo.insert()

      config ->
        {:ok, config}
    end
  end

  @doc """
  Updates the multiplier for a participant on a ticket.
  Creates the config if it doesn't exist.
  """
  def update_participant_multiplier(ticket_id, participant_name, multiplier) do
    participant_name = String.trim(participant_name)

    case get_or_create_participant_config(ticket_id, participant_name) do
      {:ok, config} ->
        config
        |> ParticipantConfig.changeset(%{multiplier: multiplier})
        |> Repo.update()

      error ->
        error
    end
  end

  @doc """
  Gets the multiplier for a participant on a ticket.
  Returns 1 if no config exists.
  """
  def get_participant_multiplier(ticket_id, participant_name) do
    case get_participant_config(ticket_id, participant_name) do
      nil -> 1
      config -> config.multiplier
    end
  end

  @doc """
  Gets all participant configs for a ticket.
  """
  def list_participant_configs(ticket_id) do
    ParticipantConfig
    |> where([pc], pc.ticket_id == ^ticket_id)
    |> Repo.all()
  end

  @doc """
  Calculates the total amount a participant owes on a ticket.
  Uses units_assigned to calculate the cost.
  """
  def calculate_participant_total(ticket_id, participant_name) do
    # Normalize name to lowercase for case-insensitive comparison
    participant_name = String.trim(participant_name)

    # Use main context for cross-context call
    ticket = TicketSplitter.Tickets.get_ticket_with_products!(ticket_id)
    total_participants = ticket.total_participants

    ticket.products
    |> Enum.reduce(Decimal.new("0"), fn product, acc ->
      # Calculate common share (from both is_common and common_units)
      common_cost = TicketCalculator.calculate_common_cost(product, total_participants)

      # Calculate personal assignment cost
      personal_cost = TicketCalculator.calculate_personal_cost(product, participant_name)

      Decimal.add(acc, Decimal.add(common_cost, personal_cost))
    end)
  end

  @doc """
  Calculates the total amount a participant owes considering their multiplier.
  The multiplier affects how much of the common cost they pay.
  """
  def calculate_participant_total_with_multiplier(ticket_id, participant_name) do
    participant_name = String.trim(participant_name)

    # Use main context for cross-context calls
    ticket = TicketSplitter.Tickets.get_ticket_with_products!(ticket_id)
    multiplier = get_participant_multiplier(ticket_id, participant_name)

    ticket.products
    |> Enum.reduce(Decimal.new("0"), fn product, acc ->
      # Calculate common share based on total participants (physical persons) and multiplier
      common_cost =
        TicketCalculator.calculate_common_cost_with_multiplier(
          product,
          ticket.total_participants,
          multiplier
        )

      # Calculate personal assignment cost (not affected by multiplier)
      personal_cost = TicketCalculator.calculate_personal_cost(product, participant_name)

      Decimal.add(acc, Decimal.add(common_cost, personal_cost))
    end)
  end

  @doc """
  Calculates the sum of all multipliers for a ticket's participant configs.
  Returns 0 if no configs exist.
  """
  def sum_of_multipliers(ticket_id) do
    list_participant_configs(ticket_id)
    |> Enum.reduce(0, fn config, acc -> acc + config.multiplier end)
  end

  @doc """
  Ensures a participant config exists for a participant and updates total_participants if needed.
  Returns {:ok, config, :created | :exists} to indicate if it was created or already existed.
  """
  def ensure_participant_and_update_total(ticket_id, participant_name) do
    participant_name = String.trim(participant_name)

    case get_participant_config(ticket_id, participant_name) do
      nil ->
        # Create new participant config
        {:ok, config} =
          %ParticipantConfig{}
          |> ParticipantConfig.changeset(%{
            ticket_id: ticket_id,
            participant_name: participant_name,
            multiplier: 1
          })
          |> Repo.insert()

        # Increment total_participants by 1
        ticket = TicketSplitter.Tickets.get_ticket!(ticket_id)

        {:ok, _updated_ticket} =
          TicketSplitter.Tickets.update_ticket(ticket, %{
            total_participants: ticket.total_participants + 1
          })

        {:ok, config, :created}

      config ->
        {:ok, config, :exists}
    end
  end

  @doc """
  Updates a participant's multiplier and adjusts total_participants by the delta.
  """
  def update_multiplier_and_adjust_total(ticket_id, participant_name, new_multiplier) do
    participant_name = String.trim(participant_name)

    # Get or create config
    {:ok, config} = get_or_create_participant_config(ticket_id, participant_name)

    old_multiplier = config.multiplier
    delta = new_multiplier - old_multiplier

    # Update multiplier
    {:ok, updated_config} =
      config
      |> ParticipantConfig.changeset(%{multiplier: new_multiplier})
      |> Repo.update()

    # Adjust total_participants by delta
    if delta != 0 do
      ticket = TicketSplitter.Tickets.get_ticket!(ticket_id)

      {:ok, _updated_ticket} =
        TicketSplitter.Tickets.update_ticket(ticket, %{
          total_participants: ticket.total_participants + delta
        })
    end

    {:ok, updated_config}
  end
end
