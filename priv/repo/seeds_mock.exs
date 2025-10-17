# Mock data for development without database

# This is an example of how to create mock data using the Tickets context
# Run with: mix run priv/repo/seeds_mock.exs

alias TicketSplitter.Tickets

# Mock JSON response from OpenRouter
mock_products_json = %{
  "products" => [
    %{
      "name" => "HAMBURGUESA CLÁSICA",
      "units" => 2,
      "unit_price" => 12.50,
      "total_price" => 25.00,
      "confidence" => 0.95,
      "source_lines" => ["2 x HAMBURGUESA CLÁSICA 12.50"]
    },
    %{
      "name" => "PIZZA MARGHERITA",
      "units" => 1,
      "unit_price" => 15.00,
      "total_price" => 15.00,
      "confidence" => 0.98,
      "source_lines" => ["PIZZA MARGHERITA 15.00"]
    },
    %{
      "name" => "ENSALADA CÉSAR",
      "units" => 1,
      "unit_price" => 8.50,
      "total_price" => 8.50,
      "confidence" => 0.92,
      "source_lines" => ["ENSALADA CÉSAR 8.50"]
    },
    %{
      "name" => "PATATAS BRAVAS",
      "units" => 2,
      "unit_price" => 5.00,
      "total_price" => 10.00,
      "confidence" => 0.90,
      "source_lines" => ["2 x PATATAS BRAVAS 5.00"]
    },
    %{
      "name" => "COCA-COLA",
      "units" => 3,
      "unit_price" => 2.50,
      "total_price" => 7.50,
      "confidence" => 0.99,
      "source_lines" => ["3 x COCA-COLA 2.50"]
    },
    %{
      "name" => "CERVEZA",
      "units" => 2,
      "unit_price" => 3.00,
      "total_price" => 6.00,
      "confidence" => 0.95,
      "source_lines" => ["2 x CERVEZA 3.00"]
    },
    %{
      "name" => "PAN Y ALIOLI",
      "units" => 1,
      "unit_price" => 2.00,
      "total_price" => 2.00,
      "confidence" => 0.88,
      "source_lines" => ["PAN Y ALIOLI 2.00"]
    },
    %{
      "name" => "SERVICIO",
      "units" => 1,
      "unit_price" => 3.50,
      "total_price" => 3.50,
      "confidence" => 0.85,
      "source_lines" => ["SERVICIO 3.50"]
    }
  ],
  "ignored_lines" => [],
  "raw_text" => [
    "RESTAURANTE EL BUEN COMER",
    "C/ Principal, 123",
    "Tel: 123456789",
    "========================",
    "2 x HAMBURGUESA CLÁSICA 12.50",
    "PIZZA MARGHERITA 15.00",
    "ENSALADA CÉSAR 8.50",
    "2 x PATATAS BRAVAS 5.00",
    "3 x COCA-COLA 2.50",
    "2 x CERVEZA 3.00",
    "PAN Y ALIOLI 2.00",
    "SERVICIO 3.50",
    "========================",
    "TOTAL: 77.50 EUR"
  ]
}

# Create ticket with mock data
{:ok, ticket} = Tickets.create_ticket_from_json(mock_products_json, "ticket_mock.jpg")

IO.puts("✅ Mock ticket created with ID: #{ticket.id}")
IO.puts("🌐 You can access it at: http://localhost:4000/tickets/#{ticket.id}")
IO.puts("")
IO.puts("Total products: #{length(mock_products_json["products"])}")
IO.puts("Total amount: €77.50")
