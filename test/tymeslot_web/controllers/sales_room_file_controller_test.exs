defmodule TymeslotWeb.SalesRoomFileControllerTest do
  use TymeslotWeb.ConnCase, async: false

  @moduletag :bookings

  import Tymeslot.ConfigTestHelpers
  import Tymeslot.Factory

  alias Tymeslot.Plans
  alias Tymeslot.SalesRooms
  alias Tymeslot.SalesRooms.Document
  alias Tymeslot.SalesRooms.Metrics
  alias Tymeslot.SalesRooms.Storage
  alias Tymeslot.Test.UploadRoot

  setup do
    UploadRoot.isolate("sales-room-download")
    user = insert(:user)
    profile = insert(:profile, user: user)
    %{user: user, profile: profile}
  end

  test "a published pdf downloads as an attachment and counts", %{conn: conn, profile: profile} do
    path = write_pdf(profile.id)

    {:ok, document} =
      Document.put_block(Document.blank(), "documents", %{
        "enabled" => true,
        "files" => [%{"path" => path, "name" => "Nordlicht Überblick.pdf", "bytes" => 40}]
      })

    assert {:ok, _saved} = SalesRooms.save(profile, nil, nil, document)

    conn = get(conn, "/booking-files/#{profile.id}/#{Path.basename(path)}")

    assert response(conn, 200) =~ "%PDF"
    assert get_resp_header(conn, "content-type") == ["application/pdf; charset=utf-8"]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    disposition = List.first(get_resp_header(conn, "content-disposition"))
    assert disposition =~ "attachment"
    assert disposition =~ "Nordlicht"
    assert Metrics.get(profile.id, nil).document_downloads == 1
  end

  test "a free plan and an unknown file are not found", %{
    conn: conn,
    user: user,
    profile: profile
  } do
    path = write_pdf(profile.id)

    {:ok, document} =
      Document.put_block(Document.blank(), "documents", %{
        "enabled" => true,
        "files" => [%{"path" => path, "name" => "Brief.pdf", "bytes" => 20}]
      })

    assert {:ok, _saved} = SalesRooms.save(profile, nil, nil, document)

    with_config(:tymeslot, plans_enabled: true)
    Plans.invalidate(user.id)

    conn = get(conn, "/booking-files/#{profile.id}/#{Path.basename(path)}")
    assert response(conn, 404) == "Not Found"

    missing =
      get(build_conn(), "/booking-files/#{profile.id}/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.pdf")

    assert response(missing, 404) == "Not Found"
  end

  defp write_pdf(profile_id) do
    pdf = Path.join(System.tmp_dir!(), "room-#{System.unique_integer([:positive])}.pdf")
    File.write!(pdf, "%PDF-1.4\n%%EOF\n")
    {:ok, path, _bytes} = Storage.store(profile_id, :document, %{path: pdf})
    path
  end
end
