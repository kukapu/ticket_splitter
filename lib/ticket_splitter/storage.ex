defmodule TicketSplitter.Storage do
  @moduledoc """
  S3/MinIO storage operations for ticket images.
  """

  require Logger

  @doc """
  Uploads an image to S3 and returns the public URL.
  """
  def upload_image(binary_data, filename, content_type) do
    bucket = get_bucket()
    key = generate_key(filename)

    Logger.info("📤 Uploading image to S3: #{key}")

    case ExAws.S3.put_object(bucket, key, binary_data, [
           {:content_type, content_type},
           {:acl, :public_read}
         ])
         |> ExAws.request() do
      {:ok, _} ->
        url = get_public_url(key)
        Logger.info("✅ Image uploaded successfully: #{url}")
        {:ok, url}

      {:error, error} ->
        Logger.error("❌ Failed to upload image: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Uploads an error image (failed parsing) to S3 in the tickets-error folder.
  """
  def upload_error_image(binary_data, filename, content_type) do
    bucket = get_bucket()
    key = generate_error_key(filename)

    Logger.info("📤 Uploading error image to S3: #{key}")

    case ExAws.S3.put_object(bucket, key, binary_data, [
           {:content_type, content_type},
           {:acl, :public_read}
         ])
         |> ExAws.request() do
      {:ok, _} ->
        url = get_public_url(key)
        Logger.info("✅ Error image uploaded successfully: #{url}")
        {:ok, url}

      {:error, error} ->
        Logger.error("❌ Failed to upload error image: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Deletes an image from S3.
  """
  def delete_image(url) when is_binary(url) do
    key = extract_key_from_url(url)
    bucket = get_bucket()

    Logger.info("🗑️ Deleting image from S3: #{key}")

    case ExAws.S3.delete_object(bucket, key) |> ExAws.request() do
      {:ok, _} ->
        Logger.info("✅ Image deleted successfully")
        :ok

      {:error, error} ->
        Logger.error("❌ Failed to delete image: #{inspect(error)}")
        {:error, error}
    end
  end

  def delete_image(nil), do: :ok

  # Private functions

  defp get_bucket do
    Application.get_env(:ticket_splitter, :storage)[:bucket] || "ticket-splitter"
  end

  defp get_public_url(key) do
    base_url =
      Application.get_env(:ticket_splitter, :storage)[:public_url] ||
        "http://localhost:9000/ticket-splitter"

    "#{base_url}/#{key}"
  end

  defp generate_key(filename) do
    uuid = Ecto.UUID.generate()
    ext = Path.extname(filename) |> String.downcase()
    # Normalize extension for webp output
    ext = if ext == "", do: ".webp", else: ext
    "tickets/#{uuid}#{ext}"
  end

  defp generate_error_key(filename) do
    uuid = Ecto.UUID.generate()
    ext = Path.extname(filename) |> String.downcase()
    # Normalize extension for webp output
    ext = if ext == "", do: ".webp", else: ext
    "tickets-error/#{uuid}#{ext}"
  end

  defp extract_key_from_url(url) do
    base_url =
      Application.get_env(:ticket_splitter, :storage)[:public_url] ||
        "http://localhost:9000/ticket-splitter"

    String.replace(url, "#{base_url}/", "")
  end
end
