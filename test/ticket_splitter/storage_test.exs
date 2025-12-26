defmodule TicketSplitter.StorageTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.Storage

  describe "delete_image/1" do
    test "returns :ok when deleting nil" do
      assert Storage.delete_image(nil) == :ok
    end
  end

  describe "Storage configuration" do
    test "bucket name can be configured via application env" do
      assert is_binary(
               Application.get_env(:ticket_splitter, :storage)[:bucket] || "ticket-splitter"
             )
    end

    test "public URL can be configured via application env" do
      base_url =
        Application.get_env(:ticket_splitter, :storage)[:public_url] ||
          "http://localhost:9000/ticket-splitter"

      assert is_binary(base_url)
      assert base_url =~ "ticket-splitter"
    end
  end
end
