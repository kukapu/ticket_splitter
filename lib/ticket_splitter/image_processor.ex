defmodule TicketSplitter.ImageProcessor do
  @moduledoc """
  Image processing for ticket photos.

  Currently optimizes images (resize, convert to WebP).

  Note: Automatic document/ticket detection requires OpenCV for proper
  corner detection and perspective transform. This could be added later
  using the `evision` library.
  """

  require Logger

  @max_dimension 2000
  @webp_quality 85

  @doc """
  Processes an uploaded image:
  - Resizes if too large (keeping aspect ratio)
  - Converts to WebP for optimal storage

  Returns {:ok, binary_data, content_type} or {:error, reason}
  """
  def process(binary_data) when is_binary(binary_data) do
    Logger.info("🔄 Starting image processing...")

    case Image.from_binary(binary_data) do
      {:ok, image} ->
        {width, height, _} = Image.shape(image)
        Logger.info("📷 Image loaded: #{width}x#{height}")

        case optimize_image(image) do
          {:ok, optimized_binary} ->
            {:ok, optimized_binary, "image/webp"}

          error ->
            error
        end

      {:error, reason} ->
        Logger.error("❌ Failed to load image: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Optimize image: resize if needed, convert to WebP
  defp optimize_image(image) do
    Logger.info("🔧 Optimizing image...")

    with {:ok, resized} <- maybe_resize(image),
         {:ok, binary} <- to_webp(resized) do
      Logger.info("✅ Image optimized, size: #{byte_size(binary)} bytes")
      {:ok, binary}
    end
  end

  # Resize image if it exceeds max dimensions
  defp maybe_resize(image) do
    {width, height, _bands} = Image.shape(image)

    if width > @max_dimension or height > @max_dimension do
      Logger.info("📏 Resizing from #{width}x#{height} to max #{@max_dimension}")
      Image.thumbnail(image, @max_dimension)
    else
      Logger.info("📏 No resize needed (#{width}x#{height})")
      {:ok, image}
    end
  end

  # Convert image to WebP format
  defp to_webp(image) do
    Image.write(image, :memory, suffix: ".webp", quality: @webp_quality)
  end
end
