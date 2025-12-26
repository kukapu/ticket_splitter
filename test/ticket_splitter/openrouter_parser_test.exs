defmodule TicketSplitter.OpenRouter.ParserTest do
  use TicketSplitter.DataCase

  alias TicketSplitter.OpenRouter.Parser

  describe "parse_response/1" do
    test "parses valid response and returns products JSON" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"products": [{"name": "Coffee", "price": 5.0}]})
            }
          }
        ]
      }

      assert {:ok, json} = Parser.parse_response(response)
      assert json["products"] |> length() == 1
    end

    test "parses valid response with markdown code blocks" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s(```json\n{"products": [{"name": "Tea", "price": 3.0}]}\n```)
            }
          }
        ]
      }

      assert {:ok, json} = Parser.parse_response(response)
      assert json["products"] |> length() == 1
    end

    test "returns error when response is not a valid receipt" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"is_receipt": false, "error_message": "Not a ticket"})
            }
          }
        ]
      }

      assert {:error, :not_a_receipt, "Not a ticket"} = Parser.parse_response(response)
    end

    test "returns error when response is not a valid receipt without error message" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"is_receipt": false})
            }
          }
        ]
      }

      assert {:error, :not_a_receipt, "The uploaded image does not appear to be a valid receipt."} =
               Parser.parse_response(response)
    end

    test "returns error when content is not valid JSON" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => "not valid json"
            }
          }
        ]
      }

      assert {:error, "El contenido no es JSON válido"} = Parser.parse_response(response)
    end

    test "returns error when response format is invalid" do
      response = %{"invalid" => "format"}

      assert {:error, "Formato de respuesta inválido"} = Parser.parse_response(response)
    end

    test "returns error when choices is empty" do
      response = %{
        "choices" => []
      }

      assert {:error, "Formato de respuesta inválido"} = Parser.parse_response(response)
    end

    test "returns error when message is missing" do
      response = %{
        "choices" => [
          %{
            "invalid" => "message"
          }
        ]
      }

      assert {:error, "Formato de respuesta inválido"} = Parser.parse_response(response)
    end

    test "returns error when content is missing" do
      response = %{
        "choices" => [
          %{
            "message" => %{}
          }
        ]
      }

      assert {:error, "Formato de respuesta inválido"} = Parser.parse_response(response)
    end
  end

  describe "extract_content/1" do
    test "extracts content from valid response" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => "test content"
            }
          }
        ]
      }

      assert {:ok, "test content"} = Parser.extract_content(response)
    end

    test "returns :error when choices is missing" do
      response = %{"invalid" => "format"}

      assert :error = Parser.extract_content(response)
    end

    test "returns :error when choices is empty" do
      response = %{"choices" => []}

      assert :error = Parser.extract_content(response)
    end

    test "returns :error when message is missing" do
      response = %{
        "choices" => [
          %{
            "invalid" => "message"
          }
        ]
      }

      assert :error = Parser.extract_content(response)
    end

    test "returns :error when content is missing" do
      response = %{
        "choices" => [
          %{
            "message" => %{}
          }
        ]
      }

      assert :error = Parser.extract_content(response)
    end
  end

  describe "sanitize_json_content/1" do
    test "removes json code block at start" do
      content = ~s(```json\n{"products": []}\n```)
      sanitized = Parser.sanitize_json_content(content)
      assert sanitized == ~s({"products": []})
    end

    test "removes code block without json marker" do
      content = ~s(```\n{"products": []}\n```)
      sanitized = Parser.sanitize_json_content(content)
      assert sanitized == ~s({"products": []})
    end

    test "removes code block with extra whitespace" do
      content = ~s(```json   \n{"products": []}\n```  )
      sanitized = Parser.sanitize_json_content(content)
      assert sanitized == ~s({"products": []})
    end

    test "returns content unchanged if no code blocks" do
      content = ~s({"products": []})
      sanitized = Parser.sanitize_json_content(content)
      assert sanitized == content
    end

    test "trims whitespace" do
      content = ~s(  {"products": []}  )
      sanitized = Parser.sanitize_json_content(content)
      assert sanitized == ~s({"products": []})
    end
  end

  describe "extract_total_from_response/1" do
    test "extracts total amount when it's a number" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"total_amount": 100.50})
            }
          }
        ]
      }

      assert Parser.extract_total_from_response(response) == 100.50
    end

    test "extracts total amount when it's a string" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"total_amount": "100.50"})
            }
          }
        ]
      }

      assert Parser.extract_total_from_response(response) == 100.50
    end

    test "returns nil when total_amount is missing" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"products": []})
            }
          }
        ]
      }

      assert Parser.extract_total_from_response(response) == nil
    end

    test "returns nil when total_amount is invalid string" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"total_amount": "invalid"})
            }
          }
        ]
      }

      assert Parser.extract_total_from_response(response) == nil
    end

    test "returns nil when response is invalid" do
      response = %{"invalid" => "format"}

      assert Parser.extract_total_from_response(response) == nil
    end
  end

  describe "check_if_receipt/1" do
    test "returns :ok when is_receipt is true or missing" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"products": []})
            }
          }
        ]
      }

      assert :ok = Parser.check_if_receipt(response)
    end

    test "returns error when is_receipt is false with error message" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"is_receipt": false, "error_message": "Not a ticket"})
            }
          }
        ]
      }

      assert {:error, :not_a_receipt, "Not a ticket"} = Parser.check_if_receipt(response)
    end

    test "returns error when is_receipt is false without error message" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => ~s({"is_receipt": false})
            }
          }
        ]
      }

      assert {:error, :not_a_receipt, "The uploaded image does not appear to be a valid receipt."} =
               Parser.check_if_receipt(response)
    end

    test "returns :ok when response is invalid" do
      response = %{invalid: "format"}

      assert :ok = Parser.check_if_receipt(response)
    end
  end
end
