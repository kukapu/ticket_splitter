defmodule TicketSplitter.Tickets.ParticipantAssignmentTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.Tickets.ParticipantAssignment
  import TicketSplitter.TicketsFixtures

  describe "changeset/2 validations" do
    setup do
      product = product_fixture()

      valid_attrs = %{
        product_id: product.id,
        participant_name: "Alice",
        units_assigned: Decimal.new("2.0"),
        percentage: Decimal.new("100"),
        assigned_color: "#FF0000",
        assignment_group_id: Ecto.UUID.generate()
      }

      %{valid_attrs: valid_attrs, product: product}
    end

    test "accepts valid attributes", %{valid_attrs: attrs} do
      changeset = ParticipantAssignment.changeset(%ParticipantAssignment{}, attrs)

      assert changeset.valid?
    end

    test "requires product_id", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(%ParticipantAssignment{}, Map.delete(attrs, :product_id))

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).product_id
    end

    test "requires participant_name", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          Map.delete(attrs, :participant_name)
        )

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).participant_name
    end

    test "accepts nil percentage", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(%ParticipantAssignment{}, Map.put(attrs, :percentage, nil))

      assert changeset.valid?
    end

    test "accepts nil units_assigned", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          Map.put(attrs, :units_assigned, nil)
        )

      assert changeset.valid?
    end

    test "accepts nil assigned_color", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          Map.put(attrs, :assigned_color, nil)
        )

      assert changeset.valid?
    end

    test "accepts nil assignment_group_id", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          Map.put(attrs, :assignment_group_id, nil)
        )

      assert changeset.valid?
    end

    test "rejects percentage greater than 100", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          %{attrs | percentage: Decimal.new("150")}
        )

      refute changeset.valid?
      assert "must be less than or equal to 100" in errors_on(changeset).percentage
    end

    test "rejects percentage less than 0", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          %{attrs | percentage: Decimal.new("-10")}
        )

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).percentage
    end

    test "accepts percentage equal to 0", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          %{attrs | percentage: Decimal.new("0")}
        )

      assert changeset.valid?
    end

    test "accepts percentage equal to 100", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          %{attrs | percentage: Decimal.new("100")}
        )

      assert changeset.valid?
    end

    test "accepts percentage with decimals (50.5)", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          %{attrs | percentage: Decimal.new("50.5")}
        )

      assert changeset.valid?
    end

    test "rejects negative units_assigned", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          %{attrs | units_assigned: Decimal.new("-1")}
        )

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).units_assigned
    end

    test "accepts zero units_assigned", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          %{attrs | units_assigned: Decimal.new("0")}
        )

      assert changeset.valid?
    end

    test "accepts fractional units_assigned (0.5)", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          %{attrs | units_assigned: Decimal.new("0.5")}
        )

      assert changeset.valid?
    end

    test "accepts large units_assigned (1000)", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(
          %ParticipantAssignment{},
          %{attrs | units_assigned: Decimal.new("1000")}
        )

      assert changeset.valid?
    end

    test "validates foreign_key_constraint on invalid product_id" do
      invalid_attrs = %{
        product_id: Ecto.UUID.generate(),
        participant_name: "Alice",
        units_assigned: Decimal.new("1"),
        percentage: Decimal.new("100")
      }

      {:error, changeset} =
        %ParticipantAssignment{}
        |> ParticipantAssignment.changeset(invalid_attrs)
        |> Repo.insert()

      assert "does not exist" in errors_on(changeset).product_id
    end

    test "accepts various color formats", %{valid_attrs: attrs} do
      colors = ["#FF0000", "#00FF00", "#0000FF", "#ABC123", "#FFFFFF", "#000000"]

      for color <- colors do
        changeset =
          ParticipantAssignment.changeset(%ParticipantAssignment{}, %{
            attrs
            | assigned_color: color
          })

        assert changeset.valid?, "Color #{color} should be valid"
      end
    end

    test "accepts participant names with spaces", %{valid_attrs: attrs} do
      changeset =
        ParticipantAssignment.changeset(%ParticipantAssignment{}, %{
          attrs
          | participant_name: "Alice Smith"
        })

      assert changeset.valid?
    end

    test "accepts participant names with special characters", %{valid_attrs: attrs} do
      names = ["Alice-Bob", "María José", "O'Connor", "Jean-Pierre"]

      for name <- names do
        changeset =
          ParticipantAssignment.changeset(%ParticipantAssignment{}, %{
            attrs
            | participant_name: name
          })

        assert changeset.valid?, "Name #{name} should be valid"
      end
    end
  end

  describe "changeset/2 edge cases" do
    test "accepts minimum valid assignment (only required fields)" do
      product = product_fixture()

      changeset =
        ParticipantAssignment.changeset(%ParticipantAssignment{}, %{
          product_id: product.id,
          participant_name: "Bob"
        })

      assert changeset.valid?
    end

    test "accepts assignment with all fields populated" do
      product = product_fixture()

      changeset =
        ParticipantAssignment.changeset(%ParticipantAssignment{}, %{
          product_id: product.id,
          participant_name: "Charlie Complete",
          units_assigned: Decimal.new("7.5"),
          percentage: Decimal.new("33.33"),
          assigned_color: "#AB12CD",
          assignment_group_id: Ecto.UUID.generate()
        })

      assert changeset.valid?
    end
  end

  describe "database constraints" do
    test "allows multiple assignments for same participant on different products" do
      ticket = ticket_fixture()
      product1 = product_fixture(ticket_id: ticket.id)
      product2 = product_fixture(ticket_id: ticket.id)

      {:ok, _assignment1} =
        %ParticipantAssignment{}
        |> ParticipantAssignment.changeset(%{
          product_id: product1.id,
          participant_name: "Alice"
        })
        |> Repo.insert()

      {:ok, _assignment2} =
        %ParticipantAssignment{}
        |> ParticipantAssignment.changeset(%{
          product_id: product2.id,
          participant_name: "Alice"
        })
        |> Repo.insert()

      # Should succeed - same participant can have assignments on different products
      assignments =
        Repo.all(
          from a in ParticipantAssignment,
            where: a.participant_name == "Alice"
        )

      assert length(assignments) == 2
    end

    test "allows multiple assignments for same product with different group_ids" do
      product = product_fixture()
      group1 = Ecto.UUID.generate()
      group2 = Ecto.UUID.generate()

      {:ok, _assignment1} =
        %ParticipantAssignment{}
        |> ParticipantAssignment.changeset(%{
          product_id: product.id,
          participant_name: "Alice",
          assignment_group_id: group1
        })
        |> Repo.insert()

      {:ok, _assignment2} =
        %ParticipantAssignment{}
        |> ParticipantAssignment.changeset(%{
          product_id: product.id,
          participant_name: "Alice",
          assignment_group_id: group2
        })
        |> Repo.insert()

      assignments =
        Repo.all(
          from a in ParticipantAssignment,
            where: a.product_id == ^product.id and a.participant_name == "Alice"
        )

      assert length(assignments) == 2
    end
  end
end
