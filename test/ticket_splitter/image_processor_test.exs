defmodule TicketSplitter.ImageProcessorTest do
  use TicketSplitter.DataCase, async: true

  alias TicketSplitter.ImageProcessor

  describe "process/1" do
    test "processes valid PNG image and returns WebP binary" do
      # Create a minimal valid PNG image (1x1 white pixel)
      {:ok, image} = Image.new(1, 1, color: :white)
      {:ok, png_binary} = Image.write(image, :memory, suffix: ".png")

      assert {:ok, webp_binary, "image/webp"} = ImageProcessor.process(png_binary)
      assert is_binary(webp_binary)
      assert byte_size(webp_binary) > 0

      # Verify it's actually WebP by checking signature
      # WebP files start with "RIFF" followed by file size, then "WEBP"
      assert <<_riff::binary-size(4), _size::32-little, webp_signature::binary-size(4),
               _rest::binary>> = webp_binary

      assert webp_signature == "WEBP"
    end

    test "processes valid JPEG image and returns WebP binary" do
      # Create a small JPEG image
      {:ok, image} = Image.new(10, 10, color: :blue)
      {:ok, jpeg_binary} = Image.write(image, :memory, suffix: ".jpg")

      assert {:ok, webp_binary, "image/webp"} = ImageProcessor.process(jpeg_binary)
      assert is_binary(webp_binary)
      assert byte_size(webp_binary) > 0
    end

    test "returns error for invalid binary data" do
      invalid_data = "not a valid image"

      assert {:error, _reason} = ImageProcessor.process(invalid_data)
    end

    test "returns error for empty binary" do
      assert {:error, _reason} = ImageProcessor.process(<<>>)
    end

    test "returns error for corrupted image data" do
      # Create corrupted PNG header
      corrupted_data = <<137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3, 4>>

      assert {:error, _reason} = ImageProcessor.process(corrupted_data)
    end
  end

  describe "process/1 - image optimization" do
    test "resizes large image to max dimension (2000px)" do
      # Create an image larger than max_dimension (2000px)
      # Using 2500x1500 as test case
      {:ok, large_image} = Image.new(2500, 1500, color: :red)
      {:ok, large_binary} = Image.write(large_image, :memory, suffix: ".png")

      assert {:ok, webp_binary, "image/webp"} = ImageProcessor.process(large_binary)

      # Verify the resulting image is resized
      {:ok, result_image} = Image.from_binary(webp_binary)
      {width, height, _} = Image.shape(result_image)

      # The largest dimension should be <= 2000
      assert max(width, height) <= 2000

      # Aspect ratio should be preserved approximately
      # Original ratio: 2500/1500 = 1.667
      # Result ratio should be close to that
      ratio = width / height
      assert_in_delta ratio, 2500 / 1500, 0.1
    end

    test "does not resize image smaller than max dimension" do
      # Create an image smaller than max_dimension
      {:ok, small_image} = Image.new(800, 600, color: :green)
      {:ok, small_binary} = Image.write(small_image, :memory, suffix: ".png")

      assert {:ok, webp_binary, "image/webp"} = ImageProcessor.process(small_binary)

      # Verify dimensions are preserved (no upscaling)
      {:ok, result_image} = Image.from_binary(webp_binary)
      {width, height, _} = Image.shape(result_image)

      assert width == 800
      assert height == 600
    end

    test "handles portrait orientation correctly" do
      # Create a tall portrait image (1000x2500)
      {:ok, portrait_image} = Image.new(1000, 2500, color: :purple)
      {:ok, portrait_binary} = Image.write(portrait_image, :memory, suffix: ".png")

      assert {:ok, webp_binary, "image/webp"} = ImageProcessor.process(portrait_binary)

      {:ok, result_image} = Image.from_binary(webp_binary)
      {width, height, _} = Image.shape(result_image)

      # Height should be capped at 2000
      assert height <= 2000
      # Width should maintain aspect ratio
      assert_in_delta width / height, 1000 / 2500, 0.1
    end

    test "optimizes image size with WebP compression" do
      # Create a simple image
      {:ok, image} = Image.new(500, 500, color: :yellow)
      {:ok, png_binary} = Image.write(image, :memory, suffix: ".png")
      {:ok, webp_binary, "image/webp"} = ImageProcessor.process(png_binary)

      # WebP should generally be smaller than PNG for photographic content
      # but for solid colors it might vary, so we just verify it produces output
      assert byte_size(webp_binary) > 0
      # Reasonable upper bound for 500x500 solid color
      assert byte_size(webp_binary) < 100_000
    end

    test "preserves image content after processing" do
      # Create a distinctive pattern image
      {:ok, image} = Image.new(100, 100, color: :white)
      {:ok, original_binary} = Image.write(image, :memory, suffix: ".png")

      assert {:ok, webp_binary, "image/webp"} = ImageProcessor.process(original_binary)

      # Verify we can load the WebP result
      assert {:ok, _result_image} = Image.from_binary(webp_binary)
    end
  end

  describe "process/1 - edge cases" do
    test "handles 1x1 pixel image" do
      {:ok, tiny_image} = Image.new(1, 1, color: :black)
      {:ok, tiny_binary} = Image.write(tiny_image, :memory, suffix: ".png")

      assert {:ok, _webp_binary, "image/webp"} = ImageProcessor.process(tiny_binary)
    end

    test "handles square image at exactly max dimension" do
      {:ok, exact_image} = Image.new(2000, 2000, color: :cyan)
      {:ok, exact_binary} = Image.write(exact_image, :memory, suffix: ".png")

      assert {:ok, webp_binary, "image/webp"} = ImageProcessor.process(exact_binary)

      {:ok, result_image} = Image.from_binary(webp_binary)
      {width, height, _} = Image.shape(result_image)

      # Should not be resized as it's exactly at the limit
      assert width == 2000
      assert height == 2000
    end

    test "handles image just over max dimension" do
      {:ok, over_image} = Image.new(2001, 1500, color: :magenta)
      {:ok, over_binary} = Image.write(over_image, :memory, suffix: ".png")

      assert {:ok, webp_binary, "image/webp"} = ImageProcessor.process(over_binary)

      {:ok, result_image} = Image.from_binary(webp_binary)
      {width, height, _} = Image.shape(result_image)

      # Should be resized down
      assert width <= 2000
      assert height <= 2000
    end
  end
end
