defmodule TicketSplitter.OpenRouter.PromptTest do
  use TicketSplitter.DataCase

  alias TicketSplitter.OpenRouter.Prompt

  describe "main_prompt/0" do
    test "returns a non-empty string" do
      prompt = Prompt.main_prompt()
      assert is_binary(prompt)
      assert String.length(prompt) > 0
    end

    test "returns trimmed content" do
      prompt = Prompt.main_prompt()
      assert prompt == String.trim(prompt)
    end
  end

  describe "validation_prompt/0" do
    test "returns a non-empty string" do
      prompt = Prompt.validation_prompt()
      assert is_binary(prompt)
      assert String.length(prompt) > 0
    end

    test "mentions total_amount in the prompt" do
      prompt = Prompt.validation_prompt()
      assert String.contains?(prompt, "total_amount")
    end
  end
end
