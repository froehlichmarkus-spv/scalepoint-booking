defmodule TymeslotWeb.SalesRoomFileController do
  @moduledoc """
  Sends a brochure. The file is not on the public upload mount, the response
  cannot be sniffed into another type, and a script inside the PDF has no
  origin to run against.
  """

  use TymeslotWeb, :controller

  alias Tymeslot.SalesRooms

  def show(conn, %{"room_id" => room_id, "file_id" => file_id}) do
    case SalesRooms.public_file(room_id, file_id) do
      {:ok, room, file, absolute} ->
        SalesRooms.record_download(room.id, file["id"])
        name = safe_filename(file["filename"] || file["title"] || "document.pdf")

        conn
        |> put_resp_header("x-content-type-options", "nosniff")
        |> put_resp_header("content-security-policy", "default-src 'none'; sandbox")
        |> put_resp_header("content-disposition", "attachment; filename=\"#{name}\"")
        |> put_resp_content_type("application/pdf")
        |> send_file(200, absolute)

      :error ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Not Found")
    end
  end

  defp safe_filename(name) do
    name
    |> Path.basename()
    |> String.replace(~r/[^\w.\- ]/u, "")
    |> String.slice(0, 120)
    |> case do
      "" ->
        "document.pdf"

      other ->
        if String.ends_with?(String.downcase(other), ".pdf"), do: other, else: other <> ".pdf"
    end
  end
end
