defmodule TicketSplitter.OpenRouter.ClientTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.OpenRouter.Client

  describe "base_url/0" do
    test "returns OpenRouter API endpoint" do
      assert Client.base_url() == "https://openrouter.ai/api/v1/chat/completions"
    end
  end
end
