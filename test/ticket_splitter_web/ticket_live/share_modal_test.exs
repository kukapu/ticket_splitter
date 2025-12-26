defmodule TicketSplitterWeb.TicketLive.ShareModalTest do
  use TicketSplitterWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import TicketSplitter.TicketsFixtures

  alias TicketSplitter.Tickets

  describe "render/1" do
    test "renders share modal" do
      ticket = ticket_fixture()

      html =
        render_component(&TicketSplitterWeb.TicketLive.ShareModal.render/1, %{
          id: "share-modal",
          ticket: ticket,
          locale: "en"
        })

      assert html =~ "Share Ticket"
      assert html =~ "Scan this QR code to access the ticket"
    end

    test "displays ticket URL" do
      ticket = ticket_fixture()

      html =
        render_component(&TicketSplitterWeb.TicketLive.ShareModal.render/1, %{
          id: "share-modal",
          ticket: ticket,
          locale: "en"
        })

      assert html =~ "Ticket link"
      assert html =~ "/en/tickets/#{ticket.id}"
    end

    test "displays QR code container" do
      ticket = ticket_fixture()

      html =
        render_component(&TicketSplitterWeb.TicketLive.ShareModal.render/1, %{
          id: "share-modal",
          ticket: ticket,
          locale: "en"
        })

      assert html =~ "qr-code-container"
      assert html =~ "phx-hook=\"QRCodeGenerator\""
    end
  end

  describe "share buttons" do
    test "displays WhatsApp share button" do
      ticket = ticket_fixture()

      html =
        render_component(&TicketSplitterWeb.TicketLive.ShareModal.render/1, %{
          id: "share-modal",
          ticket: ticket,
          locale: "en"
        })

      assert html =~ "WhatsApp"
      assert html =~ "wa.me"
    end

    test "displays Email share button" do
      ticket = ticket_fixture()

      html =
        render_component(&TicketSplitterWeb.TicketLive.ShareModal.render/1, %{
          id: "share-modal",
          ticket: ticket,
          locale: "en"
        })

      assert html =~ "Email"
      assert html =~ "mailto:"
    end

    test "displays Telegram share button" do
      ticket = ticket_fixture()

      html =
        render_component(&TicketSplitterWeb.TicketLive.ShareModal.render/1, %{
          id: "share-modal",
          ticket: ticket,
          locale: "en"
        })

      assert html =~ "Telegram"
      assert html =~ "t.me/share/url"
    end

    test "displays Twitter share button" do
      ticket = ticket_fixture()

      html =
        render_component(&TicketSplitterWeb.TicketLive.ShareModal.render/1, %{
          id: "share-modal",
          ticket: ticket,
          locale: "en"
        })

      assert html =~ "Twitter"
      assert html =~ "twitter.com/intent/tweet"
    end
  end

  describe "close button" do
    test "displays close button" do
      ticket = ticket_fixture()

      html =
        render_component(&TicketSplitterWeb.TicketLive.ShareModal.render/1, %{
          id: "share-modal",
          ticket: ticket,
          locale: "en"
        })

      assert html =~ "phx-click=\"close_share_modal\""
    end
  end

  describe "copy to clipboard button" do
    test "displays copy button with correct hook" do
      ticket = ticket_fixture()

      html =
        render_component(&TicketSplitterWeb.TicketLive.ShareModal.render/1, %{
          id: "share-modal",
          ticket: ticket,
          locale: "en"
        })

      assert html =~ "copy-url-button"
      assert html =~ "phx-hook=\"CopyToClipboard\""
    end
  end
end
