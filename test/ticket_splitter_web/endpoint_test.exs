defmodule TicketSplitterWeb.EndpointTest do
  use TicketSplitterWeb.ConnCase

  alias TicketSplitterWeb.Endpoint

  describe "host/0" do
    test "returns configured host" do
      assert is_binary(Endpoint.host())
      assert String.length(Endpoint.host()) > 0
    end
  end

  describe "url/0" do
    test "returns configured URL" do
      assert is_binary(Endpoint.url())
      assert String.starts_with?(Endpoint.url(), "http")
    end
  end
end
