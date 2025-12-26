defmodule TicketSplitter.Tickets do
  @moduledoc """
  The Tickets context - Main API facade.

  This module delegates to specialized sub-contexts for better maintainability.
  All public API remains unchanged.
  """

  alias TicketSplitter.Tickets.Contexts.{
    TicketOperations,
    ProductOperations,
    AssignmentOperations,
    ParticipantConfigOperations
  }

  # ============================================================================
  # Ticket Operations
  # ============================================================================

  defdelegate list_tickets(), to: TicketOperations
  defdelegate get_ticket!(id), to: TicketOperations
  defdelegate get_ticket_with_products(id), to: TicketOperations
  defdelegate get_ticket_with_products!(id), to: TicketOperations
  defdelegate create_ticket(attrs \\ %{}), to: TicketOperations
  defdelegate update_ticket(ticket, attrs), to: TicketOperations
  defdelegate delete_ticket(ticket), to: TicketOperations
  defdelegate change_ticket(ticket, attrs \\ %{}), to: TicketOperations
  defdelegate create_ticket_from_json(products_json, image_url \\ nil), to: TicketOperations

  # ============================================================================
  # Product Operations
  # ============================================================================

  defdelegate list_products_by_ticket(ticket_id), to: ProductOperations
  defdelegate get_product!(id), to: ProductOperations
  defdelegate get_product_with_assignments!(id), to: ProductOperations
  defdelegate create_product(attrs \\ %{}), to: ProductOperations
  defdelegate update_product(product, attrs), to: ProductOperations
  defdelegate delete_product(product), to: ProductOperations
  defdelegate toggle_product_common(product), to: ProductOperations
  defdelegate make_product_common(product), to: ProductOperations
  defdelegate make_product_not_common(product), to: ProductOperations
  defdelegate add_common_units(product_id, units_to_add \\ 1), to: ProductOperations
  defdelegate remove_common_units(product_id, units_to_remove \\ 1), to: ProductOperations
  defdelegate get_available_units(product_id), to: ProductOperations

  # ============================================================================
  # Assignment Operations
  # ============================================================================

  defdelegate list_assignments_by_product(product_id), to: AssignmentOperations

  defdelegate get_participant_assignments_by_ticket(ticket_id, participant_name),
    to: AssignmentOperations

  defdelegate get_participant_assignment!(id), to: AssignmentOperations
  defdelegate create_participant_assignment(attrs \\ %{}), to: AssignmentOperations
  defdelegate update_participant_assignment(assignment, attrs), to: AssignmentOperations
  defdelegate delete_participant_assignment(assignment), to: AssignmentOperations
  defdelegate add_participant_unit(product_id, participant_name, color), to: AssignmentOperations

  defdelegate join_assignment_group(assignment_group_id, participant_name, color),
    to: AssignmentOperations

  defdelegate remove_from_assignment_group(assignment_group_id, participant_name),
    to: AssignmentOperations

  defdelegate remove_participant_unit(product_id, participant_name, target_group_id \\ nil),
    to: AssignmentOperations

  defdelegate recalculate_group_percentages(assignment_group_id), to: AssignmentOperations
  defdelegate get_total_assigned_units(product_id), to: AssignmentOperations
  defdelegate recalculate_percentages(product_id), to: AssignmentOperations
  defdelegate update_custom_percentages(updates), to: AssignmentOperations

  defdelegate update_split_percentages(
                group_id,
                participant1_percentage,
                participant2_percentage
              ),
              to: AssignmentOperations

  defdelegate get_ticket_participants(ticket_id), to: AssignmentOperations
  defdelegate update_participant_name(ticket_id, old_name, new_name), to: AssignmentOperations
  defdelegate participant_name_exists?(ticket_id, participant_name), to: AssignmentOperations
  defdelegate participant_has_assignments?(ticket_id, participant_name), to: AssignmentOperations

  # ============================================================================
  # Participant Config Operations
  # ============================================================================

  defdelegate get_participant_config(ticket_id, participant_name), to: ParticipantConfigOperations

  defdelegate get_or_create_participant_config(ticket_id, participant_name),
    to: ParticipantConfigOperations

  defdelegate update_participant_multiplier(ticket_id, participant_name, multiplier),
    to: ParticipantConfigOperations

  defdelegate get_participant_multiplier(ticket_id, participant_name),
    to: ParticipantConfigOperations

  defdelegate list_participant_configs(ticket_id), to: ParticipantConfigOperations

  defdelegate calculate_participant_total(ticket_id, participant_name),
    to: ParticipantConfigOperations

  defdelegate calculate_participant_total_with_multiplier(ticket_id, participant_name),
    to: ParticipantConfigOperations

  defdelegate sum_of_multipliers(ticket_id), to: ParticipantConfigOperations

  defdelegate ensure_participant_and_update_total(ticket_id, participant_name),
    to: ParticipantConfigOperations

  defdelegate update_multiplier_and_adjust_total(ticket_id, participant_name, new_multiplier),
    to: ParticipantConfigOperations
end
