defmodule TicketSplitter.OpenRouter.ValidatorTest do
  use TicketSplitter.DataCase

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
  end
end
