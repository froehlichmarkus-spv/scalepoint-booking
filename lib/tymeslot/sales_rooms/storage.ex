defmodule Tymeslot.SalesRooms.Storage do
  @moduledoc """
  Stores a sales-room upload with the app's existing upload root.

  Images and videos are checked by their bytes, stripped of metadata and
  named by the server. PDFs are checked by their header and are not served
  from `/uploads`: the download controller reads them and sends them as
  attachments. The static allowlist does not include `.pdf`.
  """

  alias Tymeslot.Media.ImageMetadata
  alias Tymeslot.Media.MediaValidator
  alias Tymeslot.Media.Uploads
  alias Tymeslot.Media.VideoMetadata

  @document_max_bytes 20_000_000
  @video_max_bytes 40_000_000

  @type upload :: %{
          required(:path) => Path.t(),
          optional(:filename) => String.t(),
          optional(:client_name) => String.t()
        }

  @doc "Largest PDF a sales room accepts, in bytes."
  @spec document_max_bytes() :: pos_integer()
  def document_max_bytes, do: @document_max_bytes

  @doc "Largest video a sales room accepts, in bytes."
  @spec video_max_bytes() :: pos_integer()
  def video_max_bytes, do: @video_max_bytes

  @doc "Extensions the dashboard upload input may offer for `kind`."
  @spec accept(:image | :video | :document) :: [String.t()]
  def accept(:image), do: Uploads.allowed_extensions(:image)
  def accept(:video), do: ~w(.mp4 .webm)
  def accept(:document), do: ~w(.pdf)

  @spec max_bytes(:image | :video | :document) :: pos_integer()
  def max_bytes(:image), do: Uploads.max_file_size(:image)
  def max_bytes(:video), do: @video_max_bytes
  def max_bytes(:document), do: @document_max_bytes

  @doc """
  Stores `upload` for `profile_id`. Returns the path relative to the upload
  root, and for a PDF also the byte size.
  """
  @spec store(integer(), :image | :video | :document, upload()) ::
          {:ok, String.t()} | {:ok, String.t(), non_neg_integer()} | {:error, term()}
  def store(profile_id, kind, %{path: temp_path})
      when is_integer(profile_id) and kind in [:image, :video, :document] do
    with {:ok, size} <- measured_size(kind, temp_path),
         :ok <- content_ok?(kind, temp_path),
         {:ok, extension} <- extension(kind, temp_path),
         :ok <- strip(kind, temp_path, extension) do
      dest = Path.join(["sales_rooms", Integer.to_string(profile_id), folder(kind)])

      with {:ok, name} <-
             Uploads.store_atomically(temp_path, dest, Uploads.stored_name(extension), %{
               operation: :store_sales_room_asset,
               kind: kind,
               profile_id: profile_id
             }) do
        relative = Path.join(dest, name)
        if kind == :document, do: {:ok, relative, size}, else: {:ok, relative}
      end
    end
  end

  @doc "Removes a stored sales-room file. A missing file counts as removed."
  @spec delete(String.t() | nil) :: :ok | {:error, term()}
  def delete(nil), do: :ok
  def delete(""), do: :ok

  def delete(path) when is_binary(path) do
    if String.starts_with?(path, "sales_rooms/") do
      Uploads.delete_safely(path, %{operation: :delete_sales_room_asset})
    else
      {:error, :refused}
    end
  end

  @doc "Public URL of an image or video. PDFs are not published under `/uploads`."
  @spec public_url(String.t() | nil) :: String.t() | nil
  def public_url(nil), do: nil

  def public_url(path) when is_binary(path) do
    if String.ends_with?(path, ".pdf"), do: nil, else: "/uploads/" <> path
  end

  defp measured_size(kind, path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 and size <= 99_999_999 ->
        if size <= max_bytes(kind), do: {:ok, size}, else: {:error, :too_large}

      {:ok, _stat} ->
        {:error, :too_large}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp content_ok?(:image, path) do
    if MediaValidator.valid_image_file?(path), do: :ok, else: {:error, :invalid_image_format}
  end

  defp content_ok?(:video, path) do
    if MediaValidator.valid_video_file?(path), do: :ok, else: {:error, :invalid_video_format}
  end

  defp content_ok?(:document, path) do
    if MediaValidator.valid_pdf_file?(path), do: :ok, else: {:error, :invalid_pdf}
  end

  defp extension(:image, path) do
    case ImageMetadata.extension(path) do
      {:ok, ext} ->
        if ext in Uploads.allowed_extensions(:image),
          do: {:ok, ext},
          else: {:error, :invalid_image_format}

      {:error, _reason} ->
        {:error, :invalid_image_format}
    end
  end

  defp extension(:video, path) do
    case VideoMetadata.extension(path) do
      {:ok, ext} when ext in [".mp4", ".webm"] -> {:ok, ext}
      {:ok, _other} -> {:error, :invalid_video_format}
      {:error, _reason} -> {:error, :invalid_video_format}
    end
  end

  defp extension(:document, path) do
    if MediaValidator.valid_pdf_file?(path), do: {:ok, ".pdf"}, else: {:error, :invalid_pdf}
  end

  defp strip(:image, path, extension), do: ImageMetadata.strip(path, path, extension)

  defp strip(:video, path, _extension) do
    case VideoMetadata.strip(path) do
      {:ok, _stripped} -> :ok
      {:error, _reason} -> {:error, :invalid_video_format}
    end
  end

  defp strip(:document, _path, _extension), do: :ok

  defp folder(:image), do: "images"
  defp folder(:video), do: "videos"
  defp folder(:document), do: "documents"
end
