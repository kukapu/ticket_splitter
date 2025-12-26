defmodule TicketSplitter.Tickets.Contexts.AssignmentOperationsTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.Tickets.Contexts.AssignmentOperations
  alias TicketSplitter.Tickets.ParticipantAssignment
  alias TicketSplitter.TicketsFixtures

  describe "list_assignments_by_product/1" do
    test "returns all assignments for a product" do
      product = TicketsFixtures.product_fixture()

      assignment1 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice"
        })

      assignment2 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Bob"
        })

      assignments = AssignmentOperations.list_assignments_by_product(product.id)

      assert length(assignments) == 2
      assert assignment1.id in Enum.map(assignments, & &1.id)
      assert assignment2.id in Enum.map(assignments, & &1.id)
    end

    test "returns empty list when product has no assignments" do
      product = TicketsFixtures.product_fixture()

      assert AssignmentOperations.list_assignments_by_product(product.id) == []
    end
  end

  describe "get_participant_assignments_by_ticket/2" do
    test "returns all assignments for a participant across a ticket" do
      ticket = TicketsFixtures.ticket_fixture()
      product1 = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})
      product2 = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})

      assignment1 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product1.id,
          participant_name: "Alice"
        })

      assignment2 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product2.id,
          participant_name: "Alice"
        })

      _assignment3 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product1.id,
          participant_name: "Bob"
        })

      assignments = AssignmentOperations.get_participant_assignments_by_ticket(ticket.id, "Alice")

      assert length(assignments) == 2
      assert assignment1.id in Enum.map(assignments, & &1.id)
      assert assignment2.id in Enum.map(assignments, & &1.id)
    end

    test "returns empty list when participant has no assignments" do
      ticket = TicketsFixtures.ticket_fixture()

      assert AssignmentOperations.get_participant_assignments_by_ticket(ticket.id, "NonExistent") ==
               []
    end

    test "trims participant name whitespace" do
      ticket = TicketsFixtures.ticket_fixture()
      product = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})

      _assignment =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice"
        })

      assignments =
        AssignmentOperations.get_participant_assignments_by_ticket(ticket.id, "  Alice  ")

      assert length(assignments) == 1
    end
  end

  describe "get_participant_assignment!/1" do
    test "returns the assignment with given id" do
      assignment = TicketsFixtures.participant_assignment_fixture()

      result = AssignmentOperations.get_participant_assignment!(assignment.id)

      assert result.id == assignment.id
      assert result.participant_name == assignment.participant_name
    end

    test "raises when assignment does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        AssignmentOperations.get_participant_assignment!(Ecto.UUID.generate())
      end
    end
  end

  describe "create_participant_assignment/1" do
    test "creates assignment with valid data" do
      product = TicketsFixtures.product_fixture()

      assert {:ok, %ParticipantAssignment{} = assignment} =
               AssignmentOperations.create_participant_assignment(%{
                 product_id: product.id,
                 participant_name: "Alice",
                 units_assigned: Decimal.new("2"),
                 percentage: Decimal.new("50"),
                 assigned_color: "#FF0000"
               })

      assert assignment.participant_name == "Alice"
      assert Decimal.equal?(assignment.units_assigned, Decimal.new("2"))
      assert Decimal.equal?(assignment.percentage, Decimal.new("50"))
      assert assignment.assigned_color == "#FF0000"
    end

    test "returns error with invalid data" do
      assert {:error, %Ecto.Changeset{}} =
               AssignmentOperations.create_participant_assignment(%{
                 product_id: nil,
                 participant_name: nil
               })
    end
  end

  describe "update_participant_assignment/2" do
    test "updates assignment with valid data" do
      assignment = TicketsFixtures.participant_assignment_fixture()

      assert {:ok, updated} =
               AssignmentOperations.update_participant_assignment(assignment, %{
                 units_assigned: Decimal.new("5"),
                 percentage: Decimal.new("75")
               })

      assert Decimal.equal?(updated.units_assigned, Decimal.new("5"))
      assert Decimal.equal?(updated.percentage, Decimal.new("75"))
    end

    test "returns error with invalid data" do
      assignment = TicketsFixtures.participant_assignment_fixture()

      assert {:error, %Ecto.Changeset{}} =
               AssignmentOperations.update_participant_assignment(assignment, %{
                 percentage: Decimal.new("150")
               })
    end
  end

  describe "delete_participant_assignment/1" do
    test "deletes the assignment" do
      assignment = TicketsFixtures.participant_assignment_fixture()

      assert {:ok, %ParticipantAssignment{}} =
               AssignmentOperations.delete_participant_assignment(assignment)

      assert_raise Ecto.NoResultsError, fn ->
        AssignmentOperations.get_participant_assignment!(assignment.id)
      end
    end
  end

  describe "add_participant_unit/3" do
    test "creates new solo assignment when participant has none" do
      product = TicketsFixtures.product_fixture(%{units: 10})

      assert {:ok, assignment} =
               AssignmentOperations.add_participant_unit(product.id, "Alice", "#FF0000")

      assert assignment.participant_name == "Alice"
      assert Decimal.equal?(assignment.units_assigned, Decimal.new("1"))
      assert assignment.assigned_color == "#FF0000"
      assert Decimal.equal?(assignment.percentage, Decimal.new("100"))
      assert assignment.assignment_group_id != nil
    end

    test "increments units when participant has solo assignment" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      _initial_assignment =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice",
          units_assigned: Decimal.new("2"),
          assignment_group_id: group_id
        })

      assert {:ok, updated} =
               AssignmentOperations.add_participant_unit(product.id, "Alice", "#FF0000")

      assert Decimal.equal?(updated.units_assigned, Decimal.new("3"))
    end

    test "creates new assignment group when participant has shared assignment" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      # Create shared assignment (2 participants in same group)
      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("2"),
        assignment_group_id: group_id
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Bob",
        units_assigned: Decimal.new("2"),
        assignment_group_id: group_id
      })

      assert {:ok, new_assignment} =
               AssignmentOperations.add_participant_unit(product.id, "Alice", "#FF0000")

      # Should create new group, not increment the shared one
      assert new_assignment.assignment_group_id != group_id
      assert Decimal.equal?(new_assignment.units_assigned, Decimal.new("1"))

      # Original group should still have 2 units
      assignments = AssignmentOperations.list_assignments_by_product(product.id)

      alice_shared =
        Enum.find(assignments, fn a ->
          a.assignment_group_id == group_id and a.participant_name == "Alice"
        end)

      assert Decimal.equal?(alice_shared.units_assigned, Decimal.new("2"))
    end

    test "returns error when no units available" do
      product = TicketsFixtures.product_fixture(%{units: 2})

      # Assign all units
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("2"),
        assignment_group_id: group_id
      })

      assert {:error, :no_units_available} =
               AssignmentOperations.add_participant_unit(product.id, "Bob", "#00FF00")
    end

    test "trims participant name whitespace" do
      product = TicketsFixtures.product_fixture(%{units: 10})

      assert {:ok, assignment} =
               AssignmentOperations.add_participant_unit(product.id, "  Alice  ", "#FF0000")

      assert assignment.participant_name == "Alice"
    end
  end

  describe "join_assignment_group/3" do
    test "adds participant to existing group" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      assert {:ok, :joined} =
               AssignmentOperations.join_assignment_group(group_id, "Bob", "#00FF00")

      assignments = AssignmentOperations.list_assignments_by_product(product.id)
      bob_assignment = Enum.find(assignments, fn a -> a.participant_name == "Bob" end)

      assert bob_assignment != nil
      assert bob_assignment.assignment_group_id == group_id
      assert Decimal.equal?(bob_assignment.units_assigned, Decimal.new("3"))
    end

    test "recalculates percentages for all group members" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        percentage: Decimal.new("100"),
        assignment_group_id: group_id
      })

      AssignmentOperations.join_assignment_group(group_id, "Bob", "#00FF00")

      assignments = AssignmentOperations.list_assignments_by_product(product.id)
      alice = Enum.find(assignments, fn a -> a.participant_name == "Alice" end)
      bob = Enum.find(assignments, fn a -> a.participant_name == "Bob" end)

      # Should be split 50/50
      assert Decimal.equal?(alice.percentage, Decimal.new("50"))
      assert Decimal.equal?(bob.percentage, Decimal.new("50"))
    end

    test "returns error when group doesn't exist" do
      assert {:error, :group_not_found} =
               AssignmentOperations.join_assignment_group(
                 Ecto.UUID.generate(),
                 "Alice",
                 "#FF0000"
               )
    end

    test "returns error when participant already in group" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      assert {:error, :already_in_group} =
               AssignmentOperations.join_assignment_group(group_id, "Alice", "#FF0000")
    end

    test "trims participant name whitespace" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      assert {:ok, :joined} =
               AssignmentOperations.join_assignment_group(group_id, "  Bob  ", "#00FF00")

      assignments = AssignmentOperations.list_assignments_by_product(product.id)
      bob = Enum.find(assignments, fn a -> a.participant_name == "Bob" end)

      assert bob != nil
    end
  end

  describe "remove_from_assignment_group/2" do
    test "removes participant from group and recalculates percentages" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        percentage: Decimal.new("33.33"),
        assignment_group_id: group_id
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Bob",
        units_assigned: Decimal.new("3"),
        percentage: Decimal.new("33.33"),
        assignment_group_id: group_id
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Charlie",
        units_assigned: Decimal.new("3"),
        percentage: Decimal.new("33.34"),
        assignment_group_id: group_id
      })

      assert {:ok, :removed} =
               AssignmentOperations.remove_from_assignment_group(group_id, "Bob")

      assignments = AssignmentOperations.list_assignments_by_product(product.id)

      assert length(assignments) == 2
      assert Enum.all?(assignments, fn a -> a.participant_name != "Bob" end)

      # Remaining should be split 50/50
      alice = Enum.find(assignments, fn a -> a.participant_name == "Alice" end)
      charlie = Enum.find(assignments, fn a -> a.participant_name == "Charlie" end)

      assert Decimal.equal?(alice.percentage, Decimal.new("50"))
      assert Decimal.equal?(charlie.percentage, Decimal.new("50"))
    end

    test "removes last participant without error" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      assert {:ok, :removed} =
               AssignmentOperations.remove_from_assignment_group(group_id, "Alice")

      assignments = AssignmentOperations.list_assignments_by_product(product.id)
      assert assignments == []
    end

    test "returns error when participant not in group" do
      assert {:error, :not_in_group} =
               AssignmentOperations.remove_from_assignment_group(Ecto.UUID.generate(), "Alice")
    end
  end

  describe "remove_participant_unit/3" do
    test "subtracts one unit from solo assignment with multiple units" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      assignment =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice",
          units_assigned: Decimal.new("3"),
          assignment_group_id: group_id
        })

      AssignmentOperations.remove_participant_unit(product.id, "Alice")

      updated = Repo.get!(ParticipantAssignment, assignment.id)
      assert Decimal.equal?(updated.units_assigned, Decimal.new("2"))
    end

    test "removes assignment completely when solo has only 1 unit" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      assignment =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice",
          units_assigned: Decimal.new("1"),
          assignment_group_id: group_id
        })

      AssignmentOperations.remove_participant_unit(product.id, "Alice")

      assert Repo.get(ParticipantAssignment, assignment.id) == nil
    end

    test "removes from shared group when participant is sharing" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Bob",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      AssignmentOperations.remove_participant_unit(product.id, "Bob")

      assignments = AssignmentOperations.list_assignments_by_product(product.id)
      assert length(assignments) == 1
      assert Enum.all?(assignments, fn a -> a.participant_name != "Bob" end)
    end

    test "returns error when participant has no assignments" do
      product = TicketsFixtures.product_fixture(%{units: 10})

      assert {:error, :no_assignment} =
               AssignmentOperations.remove_participant_unit(product.id, "NonExistent")
    end

    test "prioritizes solo assignments over shared when removing" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id1 = Ecto.UUID.generate()
      group_id2 = Ecto.UUID.generate()

      # Solo assignment
      solo_assignment =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice",
          units_assigned: Decimal.new("2"),
          assignment_group_id: group_id1
        })

      # Shared assignment
      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id2
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Bob",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id2
      })

      # Should remove from solo first
      AssignmentOperations.remove_participant_unit(product.id, "Alice")

      updated_solo = Repo.get!(ParticipantAssignment, solo_assignment.id)
      assert Decimal.equal?(updated_solo.units_assigned, Decimal.new("1"))

      # Shared should still exist
      shared_assignments =
        AssignmentOperations.list_assignments_by_product(product.id)
        |> Enum.filter(fn a -> a.assignment_group_id == group_id2 end)

      assert length(shared_assignments) == 2
    end

    test "can target specific assignment group" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id1 = Ecto.UUID.generate()
      group_id2 = Ecto.UUID.generate()

      # Two different groups for Alice
      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("2"),
        assignment_group_id: group_id1
      })

      assignment2 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice",
          units_assigned: Decimal.new("3"),
          assignment_group_id: group_id2
        })

      # Target group2 specifically
      AssignmentOperations.remove_participant_unit(product.id, "Alice", group_id2)

      updated = Repo.get!(ParticipantAssignment, assignment2.id)
      assert Decimal.equal?(updated.units_assigned, Decimal.new("2"))
    end
  end

  describe "recalculate_group_percentages/1" do
    test "distributes 100% equally among 2 participants (50/50)" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      assignment1 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice",
          units_assigned: Decimal.new("3"),
          percentage: Decimal.new("0"),
          assignment_group_id: group_id
        })

      assignment2 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Bob",
          units_assigned: Decimal.new("3"),
          percentage: Decimal.new("0"),
          assignment_group_id: group_id
        })

      AssignmentOperations.recalculate_group_percentages(group_id)

      updated1 = Repo.get!(ParticipantAssignment, assignment1.id)
      updated2 = Repo.get!(ParticipantAssignment, assignment2.id)

      assert Decimal.equal?(updated1.percentage, Decimal.new("50"))
      assert Decimal.equal?(updated2.percentage, Decimal.new("50"))
    end

    test "distributes 100% equally among 3 participants" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      assignment1 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice",
          units_assigned: Decimal.new("3"),
          assignment_group_id: group_id
        })

      assignment2 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Bob",
          units_assigned: Decimal.new("3"),
          assignment_group_id: group_id
        })

      assignment3 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Charlie",
          units_assigned: Decimal.new("3"),
          assignment_group_id: group_id
        })

      AssignmentOperations.recalculate_group_percentages(group_id)

      updated1 = Repo.get!(ParticipantAssignment, assignment1.id)
      updated2 = Repo.get!(ParticipantAssignment, assignment2.id)
      updated3 = Repo.get!(ParticipantAssignment, assignment3.id)

      # Each should get 33.333... (100 / 3)
      # All three should be equal
      assert Decimal.equal?(updated1.percentage, updated2.percentage)
      assert Decimal.equal?(updated2.percentage, updated3.percentage)

      # And they should add up to around 100 (within rounding tolerance)
      total =
        Decimal.add(updated1.percentage, Decimal.add(updated2.percentage, updated3.percentage))

      # Allow small rounding differences (99.99 or 100.00 or 100.01)
      assert Decimal.compare(total, Decimal.new("99.98")) in [:gt, :eq]
      assert Decimal.compare(total, Decimal.new("100.02")) in [:lt, :eq]
    end

    test "handles empty group gracefully" do
      assert :ok = AssignmentOperations.recalculate_group_percentages(Ecto.UUID.generate())
    end
  end

  describe "get_total_assigned_units/1" do
    test "calculates total units when product has solo assignments" do
      product = TicketsFixtures.product_fixture(%{units: 10})

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("2"),
        assignment_group_id: Ecto.UUID.generate()
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Bob",
        units_assigned: Decimal.new("3"),
        assignment_group_id: Ecto.UUID.generate()
      })

      total = AssignmentOperations.get_total_assigned_units(product.id)

      assert Decimal.equal?(total, Decimal.new("5"))
    end

    test "counts shared groups only once" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Bob",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      total = AssignmentOperations.get_total_assigned_units(product.id)

      # Should be 3, not 6
      assert Decimal.equal?(total, Decimal.new("3"))
    end

    test "returns 0 for product with no assignments" do
      product = TicketsFixtures.product_fixture(%{units: 10})

      total = AssignmentOperations.get_total_assigned_units(product.id)

      assert Decimal.equal?(total, Decimal.new("0"))
    end
  end

  describe "update_split_percentages/3" do
    test "adjusts split in 2-person group (60/40)" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      assignment1 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice",
          units_assigned: Decimal.new("3"),
          percentage: Decimal.new("50"),
          assignment_group_id: group_id
        })

      assignment2 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Bob",
          units_assigned: Decimal.new("3"),
          percentage: Decimal.new("50"),
          assignment_group_id: group_id
        })

      AssignmentOperations.update_split_percentages(group_id, 60, 40)

      # Ordered alphabetically: Alice, Bob
      updated1 = Repo.get!(ParticipantAssignment, assignment1.id)
      updated2 = Repo.get!(ParticipantAssignment, assignment2.id)

      assert Decimal.equal?(updated1.percentage, Decimal.new("60"))
      assert Decimal.equal?(updated2.percentage, Decimal.new("40"))
    end

    test "returns error for groups with more than 2 participants" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Bob",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Charlie",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      assert {:error, :invalid_group_size} =
               AssignmentOperations.update_split_percentages(group_id, 50, 50)
    end

    test "returns error for groups with less than 2 participants" do
      product = TicketsFixtures.product_fixture(%{units: 10})
      group_id = Ecto.UUID.generate()

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("3"),
        assignment_group_id: group_id
      })

      assert {:error, :invalid_group_size} =
               AssignmentOperations.update_split_percentages(group_id, 100, 0)
    end
  end

  describe "get_ticket_participants/1" do
    test "returns unique list of participant names" do
      ticket = TicketsFixtures.ticket_fixture()
      product1 = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})
      product2 = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product1.id,
        participant_name: "Alice",
        assigned_color: "#FF0000"
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product2.id,
        participant_name: "Alice",
        assigned_color: "#FF0000"
      })

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product1.id,
        participant_name: "Bob",
        assigned_color: "#00FF00"
      })

      participants = AssignmentOperations.get_ticket_participants(ticket.id)

      assert length(participants) == 2
      assert %{name: "Alice", color: "#FF0000"} in participants
      assert %{name: "Bob", color: "#00FF00"} in participants
    end

    test "returns empty list for ticket with no assignments" do
      ticket = TicketsFixtures.ticket_fixture()

      assert AssignmentOperations.get_ticket_participants(ticket.id) == []
    end
  end

  describe "update_participant_name/3" do
    test "updates name in all assignments for that participant" do
      ticket = TicketsFixtures.ticket_fixture()
      product1 = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})
      product2 = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})

      assignment1 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product1.id,
          participant_name: "Alice"
        })

      assignment2 =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product2.id,
          participant_name: "Alice"
        })

      assert {:ok, count} =
               AssignmentOperations.update_participant_name(ticket.id, "Alice", "Alice Smith")

      assert count == 2

      updated1 = Repo.get!(ParticipantAssignment, assignment1.id)
      updated2 = Repo.get!(ParticipantAssignment, assignment2.id)

      assert updated1.participant_name == "Alice Smith"
      assert updated2.participant_name == "Alice Smith"
    end

    test "preserves assignment_group_id, units, percentages" do
      ticket = TicketsFixtures.ticket_fixture()
      product = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})
      group_id = Ecto.UUID.generate()

      assignment =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice",
          units_assigned: Decimal.new("5"),
          percentage: Decimal.new("75"),
          assignment_group_id: group_id
        })

      AssignmentOperations.update_participant_name(ticket.id, "Alice", "Alice Johnson")

      updated = Repo.get!(ParticipantAssignment, assignment.id)

      assert updated.participant_name == "Alice Johnson"
      assert Decimal.equal?(updated.units_assigned, Decimal.new("5"))
      assert Decimal.equal?(updated.percentage, Decimal.new("75"))
      assert updated.assignment_group_id == group_id
    end

    test "handles participant with no assignments (returns 0)" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:ok, 0} =
               AssignmentOperations.update_participant_name(ticket.id, "NonExistent", "NewName")
    end

    test "returns error when new name is empty" do
      ticket = TicketsFixtures.ticket_fixture()

      assert {:error, :empty_name} =
               AssignmentOperations.update_participant_name(ticket.id, "Alice", "")
    end

    test "trims whitespace from names" do
      ticket = TicketsFixtures.ticket_fixture()
      product = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})

      assignment =
        TicketsFixtures.participant_assignment_fixture(%{
          product_id: product.id,
          participant_name: "Alice"
        })

      AssignmentOperations.update_participant_name(ticket.id, "  Alice  ", "  Bob  ")

      updated = Repo.get!(ParticipantAssignment, assignment.id)
      assert updated.participant_name == "Bob"
    end
  end

  describe "participant_name_exists?/2" do
    test "returns true when participant has assignments" do
      ticket = TicketsFixtures.ticket_fixture()
      product = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice"
      })

      assert AssignmentOperations.participant_name_exists?(ticket.id, "Alice") == true
    end

    test "returns false when participant has no assignments" do
      ticket = TicketsFixtures.ticket_fixture()

      assert AssignmentOperations.participant_name_exists?(ticket.id, "NonExistent") == false
    end

    test "trims participant name whitespace" do
      ticket = TicketsFixtures.ticket_fixture()
      product = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice"
      })

      assert AssignmentOperations.participant_name_exists?(ticket.id, "  Alice  ") == true
    end
  end

  describe "participant_has_assignments?/2" do
    test "returns true when participant has assignments" do
      ticket = TicketsFixtures.ticket_fixture()
      product = TicketsFixtures.product_fixture(%{ticket_id: ticket.id})

      TicketsFixtures.participant_assignment_fixture(%{
        product_id: product.id,
        participant_name: "Alice"
      })

      assert AssignmentOperations.participant_has_assignments?(ticket.id, "Alice") == true
    end

    test "returns false when participant has no assignments" do
      ticket = TicketsFixtures.ticket_fixture()

      assert AssignmentOperations.participant_has_assignments?(ticket.id, "NonExistent") == false
    end
  end
end
