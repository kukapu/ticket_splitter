defmodule TicketSplitter.OpenRouter.ValidatorTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.OpenRouter.Validator

  describe "totals_match?/2" do
    test "returns true for identical values" do
      assert Validator.totals_match?(10.50, 10.50)
    end

    test "returns true for values within tolerance" do
      assert Validator.totals_match?(10.50, 10.52)
      assert Validator.totals_match?(10.50, 10.48)
    end

    test "returns false for values outside tolerance" do
      refute Validator.totals_match?(10.50, 10.60)
      refute Validator.totals_match?(10.50, 10.40)
    end

    test "returns false for nil values" do
      refute Validator.totals_match?(nil, 10.50)
      refute Validator.totals_match?(10.50, nil)
      refute Validator.totals_match?(nil, nil)
    end

    test "handles decimal strings" do
      assert Validator.totals_match?("10.50", "10.52")
      assert Validator.totals_match?(10.50, "10.52")
      assert Validator.totals_match?("10.50", 10.52)
    end

    test "tolerance is 0.05" do
      assert Validator.totals_match?(100.00, 100.05)
      refute Validator.totals_match?(100.00, 100.06)
    end

    test "handles negative differences" do
      assert Validator.totals_match?(100.00, 99.95)
      refute Validator.totals_match?(100.00, 99.94)
    end

    test "handles large values" do
      assert Validator.totals_match?(1000.00, 1000.05)
      refute Validator.totals_match?(1000.00, 1000.06)
    end

    test "handles very small differences" do
      assert Validator.totals_match?(10.00, 10.001)
      assert Validator.totals_match?(10.00, 10.01)
    end
  end
end
