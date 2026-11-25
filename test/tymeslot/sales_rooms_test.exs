defmodule Tymeslot.SalesRoomsTest do
  use Tymeslot.DataCase, async: false

  import Tymeslot.ConfigTestHelpers

  alias Tymeslot.Plans
  alias Tymeslot.Plans.AccessChecker
  alias Tymeslot.SalesRooms
  alias Tymeslot.SalesRooms.Blocks
  alias Tymeslot.SalesRooms.Embeds
  alias Tymeslot.SalesRooms.Storage

  setup do
    with_config(:tymeslot,
      plans_enabled: true,
      feature_access_checker: AccessChecker,
      plans: [trial_days: 14, comped_user_emails: [], oauth_video_providers: []]
    )

    user = insert(:user)
    profile = insert(:profile, user: user, username: "lena#{System.unique_integer([:positive])}")
    %{user: user, profile: profile}
  end

  test "catalog names the sales room and leaves team as coming soon" do
    sales = Enum.find(Plans.catalog(), &(&1.key == :sales_room))
    assert sales.free == false
    assert sales.pro == true
    assert sales.team == :coming_soon
    assert Plans.feature?(:free, :sales_room_allowed) == false
    assert Plans.feature?(:pro, :sales_room_allowed) == true
    assert Plans.feature?(:free, :powered_by_badge) == true
    assert Plans.feature?(:pro, :powered_by_badge) == false
    assert Enum.all?(Plans.catalog(), &(&1.team == :coming_soon))
  end

  test "embed allowlist accepts the three hosts and refuses anything else" do
    assert {:ok, "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"} =
             Embeds.iframe_src("https://www.youtube.com/watch?v=dQw4w9WgXcQ")

    assert {:ok, "https://player.vimeo.com/video/123456789"} =
             Embeds.iframe_src("https://vimeo.com/123456789")

    assert {:ok, "https://www.loom.com/embed/abcdefabcdefabcdefabcdefabcdefab"} =
             Embeds.iframe_src("https://www.loom.com/share/abcdefabcdefabcdefabcdefabcdefab")

    assert Embeds.iframe_src("https://evil.example/watch?v=dQw4w9WgXcQ") == :error
    assert Embeds.iframe_src("javascript:alert(1)") == :error
    assert Embeds.iframe_src("http://www.youtube.com/watch?v=dQw4w9WgXcQ") == :error
  end

  test "blocks keep a new order and reject a sixth benefit and a bad video" do
    before = Enum.find_index(Blocks.blank(), &(&1["type"] == "faq"))
    moved = Blocks.move(Blocks.blank(), "faq", :up)
    assert Enum.find_index(moved, &(&1["type"] == "faq")) == before - 1

    too_many = [
      %{
        "type" => "benefits",
        "content" => %{"items" => Enum.map(1..6, &%{"id" => "b#{&1}", "text" => "Point #{&1}"})}
      }
    ]

    assert {:error, [{:benefits, :too_many}]} = Blocks.validate(too_many)

    bad_video = Blocks.put_content(Blocks.blank(), "video", %{"url" => "https://example.com/x"})
    assert {:error, [{:video, :embed_not_allowed}]} = Blocks.validate(bad_video)
  end

  test "free keeps a saved room hidden and pro renders it", %{user: user, profile: profile} do
    assert {:error, :upgrade_required} =
             SalesRooms.save(user.id, profile.id, nil, nil, %{blocks: Blocks.blank()})

    promote(user)

    blocks =
      Blocks.blank()
      |> Blocks.put_enabled("hero", true)
      |> Blocks.put_content("hero", %{
        "headline" => "Klarheit in 45 Minuten",
        "subline" => "Für Teams"
      })
      |> Blocks.put_enabled("cta", true)
      |> Blocks.put_content("cta", %{"headline" => "Weiter", "button_label" => "Termin wählen"})

    assert {:ok, room} =
             SalesRooms.save(user.id, profile.id, nil, nil, %{blocks: blocks, accent: "#0E7C73"})

    assert room.accent == "#0e7c73"
    public = SalesRooms.public_room(profile, nil)
    assert Enum.any?(public.blocks, &(&1["content"]["headline"] == "Klarheit in 45 Minuten"))
    assert SalesRooms.accent_for(profile) == "#0e7c73"

    demote(user)
    assert SalesRooms.public_room(profile, nil) == nil
    assert SalesRooms.accent_for(profile) == nil
    kept = SalesRooms.get(profile.id, nil, nil)
    assert Enum.any?(kept.blocks, &(&1["content"]["headline"] == "Klarheit in 45 Minuten"))
  end

  test "an event type override replaces the page only while it is on", %{
    user: user,
    profile: profile
  } do
    promote(user)
    type = insert(:meeting_type, user: user, slug: "intro")

    page_blocks =
      Blocks.blank()
      |> Blocks.put_enabled("hero", true)
      |> Blocks.put_content("hero", %{"headline" => "Page"})

    type_blocks =
      Blocks.blank()
      |> Blocks.put_enabled("hero", true)
      |> Blocks.put_content("hero", %{"headline" => "Type"})

    assert {:ok, _} = SalesRooms.save(user.id, profile.id, nil, nil, %{blocks: page_blocks})

    assert {:ok, _} =
             SalesRooms.save(user.id, profile.id, nil, type.id, %{
               blocks: type_blocks,
               override: true
             })

    assert headline(SalesRooms.public_room(profile, type)) == "Type"
    assert {:ok, _} = SalesRooms.save(user.id, profile.id, nil, type.id, %{override: false})
    assert headline(SalesRooms.public_room(profile, type)) == "Page"
  end

  test "uploads reject a script, an oversized pdf and a renamed text file", %{
    user: user,
    profile: profile
  } do
    promote(user)
    dir = Path.join(System.tmp_dir!(), "sr-upload-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    png = Path.join(dir, "dot.png")

    File.write!(
      png,
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
      )
    )

    assert {:ok, path} = Storage.store_image(profile.id, png)
    assert String.starts_with?(path, "sales_rooms/")

    text = Path.join(dir, "note.png")
    File.write!(text, "<html>nope</html>")
    assert {:error, :invalid_image} = Storage.store_image(profile.id, text)

    pdf = Path.join(dir, "note.pdf")
    File.write!(pdf, "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF")
    assert {:ok, pdf_path} = Storage.store_pdf(profile.id, pdf)
    assert {:ok, absolute} = Storage.resolve(pdf_path)
    assert Bitwise.band(File.stat!(absolute).mode, 0o111) == 0

    script = Path.join(dir, "script.pdf")
    File.write!(script, "%PDF-1.4\n/JavaScript (app.alert(1))")
    assert {:error, :invalid_pdf} = Storage.store_pdf(profile.id, script)

    huge = Path.join(dir, "huge.pdf")
    File.write!(huge, "%PDF-" <> :binary.copy("a", Storage.pdf_limit()))
    assert {:error, :too_large} = Storage.store_pdf(profile.id, huge)

    fake = Path.join(dir, "clip.mp4")
    File.write!(fake, "not a video")
    assert {:error, :invalid_video} = Storage.store_video(profile.id, fake)
  end

  test "a brochure download is counted and a missing file is not", %{user: user, profile: profile} do
    promote(user)

    assert {:ok, room} =
             SalesRooms.attach(
               user.id,
               profile.id,
               nil,
               nil,
               "brochures",
               :pdf,
               write_pdf(),
               "Nordlicht.pdf"
             )

    file = hd(Enum.find(room.blocks, &(&1["type"] == "brochures"))["content"]["files"])
    assert {:ok, _room, found, path} = SalesRooms.public_file(room.id, file["id"])
    assert found["title"] == "Nordlicht.pdf"
    assert File.exists?(path)
    assert :ok = SalesRooms.record_download(room.id, file["id"])
    assert :ok = SalesRooms.record_view(room)
    fresh = SalesRooms.get(profile.id, nil, nil)
    assert fresh.page_views == 1
    assert fresh.download_counts[file["id"]] == 1
    assert SalesRooms.public_file(room.id, "nope") == :error
  end

  defp promote(user) do
    {:ok, _} =
      Plans.upsert_entitlement(%{
        "data" => %{
          "external_user_id" => "booking:#{user.id}",
          "plan" => "pro",
          "status" => "active"
        },
        "version" => 3
      })

    Plans.invalidate(user.id)
  end

  defp demote(user) do
    {:ok, _} =
      Plans.upsert_entitlement(%{
        "data" => %{
          "external_user_id" => "booking:#{user.id}",
          "plan" => "free",
          "status" => "canceled"
        },
        "version" => 4
      })

    Plans.invalidate(user.id)
  end

  defp headline(room) do
    room.blocks |> Enum.find(&(&1["type"] == "hero")) |> get_in(["content", "headline"])
  end

  defp write_pdf do
    path = Path.join(System.tmp_dir!(), "sr-#{System.unique_integer([:positive])}.pdf")
    File.write!(path, "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF")
    path
  end
end
