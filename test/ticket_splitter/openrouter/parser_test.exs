defmodule TicketSplitter.OpenRouter.ParserTest do
  use TicketSplitter.DataCase

  alias TicketSplitter.OpenRouter.Parser

  describe "sanitize_json_content/1" do
    test "removes markdown code blocks" do
      content = ~s(```json\n{"key": "value"}\n```)
      assert Parser.sanitize_json_content(content) == ~s({"key": "value"})
    end

    test "trims whitespace" do
      content = "\n  \n  {\"key\": \"value\"}  \n  "
      assert Parser.sanitize_json_content(content) == ~s({"key": "value"})
    end

    test "handles content without markdown" do
      content = ~s({"key": "value"})
      assert Parser.sanitize_json_content(content) == ~s({"key": "value"})
    end
  end

  describe "extract_content/1" do
    test "extracts content from valid response" do
      response = %{
        "choices" => [
          %{
            "message" => %{"content" => "test content"}
          }
        ]
      }

      assert {:ok, "test content"} = Parser.extract_content(response)
    end

    test "returns error for invalid response" do
      response = %{"invalid" => "structure"}
      assert :error = Parser.extract_content(response)
    end
  end

  describe "extract_total_from_response/1" do
    test "extracts total amount as number" do
      response = %{
        "choices" => [
          %{
            "message" => %{"content" => ~s({"total_amount": 24.50})}
          }
        ]
      }

      assert Parser.extract_total_from_response(response) == 24.50
    end

    test "extracts total amount as string" do
      response = %{
        "choices" => [
          %{
            "message" => %{"content" => ~s({"total_amount": "24.50"})}
          }
        ]
      }

      assert Parser.extract_total_from_response(response) == 24.50
    end

    test "returns nil when total_amount is not present" do
      response = %{
        "choices" => [
          %{
            "message" => %{"content" => ~s({"other": "value"})}
          }
        ]
      }

      assert Parser.extract_total_from_response(response) == nil
    end
  end

  describe "check_if_receipt/1" do
    test "returns :ok for valid receipt" do
      response = %{
        "choices" => [
          %{
            "message" => %{"content" => ~s({"is_receipt": true})}
          }
        ]
      }

      assert :ok = Parser.check_if_receipt(response)
    end

    test "returns error for non-receipt with message" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"is_receipt": false, "error_message": "Not a receipt"})
            }
          }
        ]
      }

      assert {:error, :not_a_receipt, "Not a receipt"} = Parser.check_if_receipt(response)
    end

    test "returns error for non-receipt without message" do
      response = %{
        "choices" => [
          %{
            "message" => %{"content" => ~s({"is_receipt": false})}
          }
        ]
      }

      assert {:error, :not_a_receipt, _} = Parser.check_if_receipt(response)
    end
  end
end
