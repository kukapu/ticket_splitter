defmodule TicketSplitter.OpenRouter.Prompt do
  @moduledoc """
  Manages prompt templates for OpenRouter API requests.
  Reads prompts from configuration files.
  """

  @doc """
  Returns the main prompt from the configuration file.
  The prompt should contain instructions for analyzing ticket images.
  """
  def main_prompt do
    prompt_path = Application.app_dir(:ticket_splitter, "priv/openrouter_prompt.txt")

    case File.read(prompt_path) do
      {:ok, content} -> String.trim(content)
      {:error, _} -> "Analiza esta imagen y describe lo que ves."
    end
  end

  @doc """
  Returns the validation prompt for cross-validation.
  This prompt requests only the total amount for validation purposes.
  """
  def validation_prompt do
    """
    Analiza la imagen y devuelve ÚNICAMENTE un objeto JSON con el total a pagar del ticket.
    Formato: {"total_amount": <numero>}.
    Si hay multiples tickets, suma los totales.
    Ejemplo: {"total_amount": 24.50}
    NO incluyas texto extra, solo el JSON.
    """
  end
end
