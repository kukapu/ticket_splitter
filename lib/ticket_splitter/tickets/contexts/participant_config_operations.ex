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
  Calculates the effective number of participants for common cost division.
  This is the sum of all multipliers for participants who have made assignments,
  plus (total_participants - actual_participants) for the "rest of participants".
  """
  def get_effective_participants_count(ticket_id) do
    # Use main context for cross-context calls
    ticket = TicketSplitter.Tickets.get_ticket!(ticket_id)
    active_participants = TicketSplitter.Tickets.get_ticket_participants(ticket_id)
    configs = list_participant_configs(ticket_id)

    # Sum multipliers for active participants
    active_multipliers_sum =
      Enum.reduce(active_participants, 0, fn participant, acc ->
        multiplier =
          Enum.find_value(configs, 1, fn config ->
            if config.participant_name == participant.name, do: config.multiplier, else: nil
          end)

        acc + multiplier
      end)

    # Add remaining (non-active) participants with multiplier of 1 each
    rest_count = max(ticket.total_participants - length(active_participants), 0)

    active_multipliers_sum + rest_count
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
    effective_participants = get_effective_participants_count(ticket_id)
    multiplier = get_participant_multiplier(ticket_id, participant_name)

    ticket.products
    |> Enum.reduce(Decimal.new("0"), fn product, acc ->
      # Calculate common share based on effective participants and multiplier
      common_cost =
        TicketCalculator.calculate_common_cost_with_multiplier(
          product,
          effective_participants,
          multiplier
        )

      # Calculate personal assignment cost (not affected by multiplier)
      personal_cost = TicketCalculator.calculate_personal_cost(product, participant_name)

      Decimal.add(acc, Decimal.add(common_cost, personal_cost))
    end)
  end
end
