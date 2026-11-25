defmodule Tymeslot.SalesRooms.Storage do
  @moduledoc """
  Stores a sales-room file with the existing upload root. The name is chosen
  here, the bytes are checked, and the file is not executable. PDFs stay out
  of the public `/uploads` mount and are sent by the download controller.
  """

  alias Tymeslot.Media.ImageMetadata
  alias Tymeslot.Media.MediaValidator
  alias Tymeslot.Media.Uploads
  alias Tymeslot.Media.VideoMetadata

  @image_bytes 20_000_000
  @pdf_bytes 20_000_000
  @video_bytes 50_000_000
  @image_exts MapSet.new([".jpg", ".jpeg", ".png", ".webp"])

  def image_limit, do: @image_bytes
  def pdf_limit, do: @pdf_bytes
  def video_limit, do: @video_bytes

  @spec store_image(integer(), Path.t()) :: {:ok, String.t()} | {:error, atom()}
  def store_image(profile_id, source) when is_integer(profile_id) and is_binary(source) do
    with :ok <- size_ok?(source, @image_bytes),
         {:ok, ext} <- image_extension(source),
         :ok <- ImageMetadata.strip(source, source, ext),
         {:ok, name} <- put(profile_id, "images", source, ext) do
      {:ok, name}
    else
      {:error, {:image_too_large, _}} -> {:error, :image_too_large}
      {:error, :busy} -> {:error, :busy}
      {:error, reason} when is_atom(reason) -> {:error, reason}
      _ -> {:error, :invalid_image}
    end
  end

  @spec store_video(integer(), Path.t()) :: {:ok, String.t()} | {:error, atom()}
  def store_video(profile_id, source) when is_integer(profile_id) and is_binary(source) do
    with :ok <- size_ok?(source, @video_bytes),
         :ok <- video_ok?(source),
         :ok <- strip_video(source),
         {:ok, ext} <- VideoMetadata.extension(source),
         {:ok, name} <- put(profile_id, "videos", source, ext) do
      {:ok, name}
    else
      {:error, reason} when is_atom(reason) -> {:error, reason}
      _ -> {:error, :invalid_video}
    end
  end

  @spec store_pdf(integer(), Path.t()) :: {:ok, String.t()} | {:error, atom()}
  def store_pdf(profile_id, source) when is_integer(profile_id) and is_binary(source) do
    with :ok <- size_ok?(source, @pdf_bytes),
         :ok <- pdf_ok?(source),
         {:ok, name} <- put(profile_id, "documents", source, ".pdf") do
      {:ok, name}
    else
      {:error, reason} when is_atom(reason) -> {:error, reason}
      _ -> {:error, :invalid_pdf}
    end
  end

  def delete(path) when is_binary(path) do
    Uploads.delete_safely(path, %{operation: :sales_room_delete})
  end

  def delete(_), do: :ok

  @doc "Absolute path inside the upload root, or an error."
  def resolve(path) when is_binary(path) do
    if String.starts_with?(path, "sales_rooms/") and not String.contains?(path, "..") do
      Uploads.resolve(path)
    else
      {:error, :path_traversal_attempt}
    end
  end

  defp put(profile_id, kind, source, ext) do
    dir = Path.join(["sales_rooms", Integer.to_string(profile_id), kind])

    with {:ok, name} <-
           Uploads.store_atomically(source, dir, Uploads.stored_name(ext), %{
             operation: :sales_room_store,
             kind: kind,
             profile_id: profile_id
           }),
         {:ok, absolute} <- Uploads.resolve(Path.join(dir, name)),
         :ok <- File.chmod(absolute, 0o640) do
      {:ok, Path.join(dir, name)}
    end
  end

  defp size_ok?(path, max) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 and size <= max -> :ok
      {:ok, %{size: size}} when size > max -> {:error, :too_large}
      _ -> {:error, :invalid_upload}
    end
  end

  defp image_extension(path) do
    case ImageMetadata.extension(path) do
      {:ok, ext} ->
        if MapSet.member?(@image_exts, ext), do: {:ok, ext}, else: {:error, :invalid_image}

      _ ->
        {:error, :invalid_image}
    end
  end

  defp video_ok?(path) do
    with {:ok, io} <- File.open(path, [:read, :binary]),
         header <- IO.binread(io, 65_536),
         :ok <- File.close(io) do
      if is_binary(header) and MediaValidator.valid_video?(header),
        do: :ok,
        else: {:error, :invalid_video}
    else
      _ -> {:error, :invalid_video}
    end
  end

  defp strip_video(path) do
    case VideoMetadata.strip(path) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :invalid_video}
    end
  end

  defp pdf_ok?(path) do
    case File.read(path) do
      {:ok, <<"%PDF-", _::binary>> = binary} ->
        if dangerous_pdf?(binary), do: {:error, :invalid_pdf}, else: :ok

      _ ->
        {:error, :invalid_pdf}
    end
  end

  defp dangerous_pdf?(binary) do
    String.contains?(binary, "/JavaScript") or String.contains?(binary, "/JS") or
      String.contains?(binary, "/Launch") or String.contains?(binary, "/OpenAction")
  end
end
