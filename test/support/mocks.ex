defmodule TicketSplitter.OpenRouter.ClientMock do
  @moduledoc false

  defmodule HTTPClient do
    @callback post(url :: String.t(), opts :: keyword()) ::
                {:ok, Req.Response.t()} | {:error, term()}
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour TicketSplitter.OpenRouter.ClientMock.HTTPClient

      def post(url, _opts) do
        case url do
          "https://openrouter.ai/api/v1/chat/completions" ->
            send(self(), {:post, url})

            receive do
              {:response, response} -> response
            after
              5000 -> {:error, :timeout}
            end

          _ ->
            {:error, :unknown_url}
        end
      end
    end
  end
end
