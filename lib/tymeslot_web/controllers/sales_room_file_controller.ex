defmodule TymeslotWeb.SalesRoomFileController do
  @moduledoc """
  Sends a sales-room PDF as a download.

  The file is not executable: the type is PDF, the browser is told not to
  sniff it, and the response is sandboxed. Direct `/uploads` requests for
  `.pdf` never reach the file.
  """

  use TymeslotWeb, :controller

  alias Tymeslot.Media.Uploads
  alias Tymeslot.SalesRooms
  alias Tymeslot.SalesRooms.Metrics

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"profile_id" => profile_id, "file" => file}) do
    with {id, ""} <- Integer.parse(profile_id),
         {:ok, path, name, page_id} <- SalesRooms.public_file(id, file),
         {:ok, absolute} <- Uploads.resolve(path),
         true <- File.regular?(absolute) do
      Metrics.record_download(id, page_id)

      conn
      |> put_resp_header("x-content-type-options", "nosniff")
      |> put_resp_header("content-security-policy", "sandbox; default-src 'none'")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{name}\"")
      |> put_resp_content_type("application/pdf")
      |> send_file(200, absolute)
    else
      _missing ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Not Found")
    end
  end
end
