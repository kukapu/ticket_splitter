defmodule TicketSplitterWeb.SEOTest do
  use TicketSplitterWeb.ConnCase, async: true

  alias TicketSplitterWeb.SEO

  describe "site_url/0" do
    test "returns site URL" do
      result = SEO.site_url()

      assert is_binary(result)
      assert String.starts_with?(result, "http://")
    end
  end

  describe "absolute_url/1" do
    test "converts relative path to absolute URL" do
      result = SEO.absolute_url("/tickets/123")

      assert is_binary(result)
      assert String.contains?(result, "tickets/123")
    end

    test "removes leading slash to avoid double slashes" do
      result = SEO.absolute_url("/tickets/123")

      refute String.contains?(result, "//tickets")
    end
  end

  describe "og_image_url/0" do
    test "returns absolute URL for OG image" do
      result = SEO.og_image_url()

      assert is_binary(result)
      assert String.contains?(result, "og-image.png")
    end
  end

  describe "default_description/0" do
    test "returns default description" do
      result = SEO.default_description()

      assert is_binary(result)
      assert String.length(result) > 0
    end
  end

  describe "page_title/1" do
    test "adds site name suffix when not present" do
      result = SEO.page_title("Test Page")

      assert result == "Test Page - Ticket Splitter"
    end

    test "returns title unchanged when site name is present" do
      result = SEO.page_title("Test Page - Ticket Splitter")

      assert result == "Test Page - Ticket Splitter"
    end

    test "returns site name when title is nil" do
      result = SEO.page_title(nil)

      assert result == "Ticket Splitter"
    end

    test "returns site name when title is empty string" do
      result = SEO.page_title("")

      assert result == " - Ticket Splitter"
    end
  end
end
