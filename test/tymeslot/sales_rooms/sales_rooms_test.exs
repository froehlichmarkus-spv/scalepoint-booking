defmodule Tymeslot.SalesRoomsTest do
  use Tymeslot.DataCase, async: false

  @moduletag :bookings

  import Tymeslot.ConfigTestHelpers
  import Tymeslot.Factory

  alias Tymeslot.Plans
  alias Tymeslot.SalesRooms
  alias Tymeslot.SalesRooms.Document
  alias Tymeslot.SalesRooms.Embeds
  alias Tymeslot.SalesRooms.Metrics
  alias Tymeslot.SalesRooms.Storage
  alias Tymeslot.Test.MediaFixtures
  alias Tymeslot.Test.UploadRoot

  setup do
    user = insert(:user)
    profile = insert(:profile, user: user)
    %{user: user, profile: profile}
  end

  test "embed urls stay on the allowlist" do
    assert Embeds.embed_src("https://www.youtube.com/watch?v=dQw4w9WgXcQ") ==
             "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"

    assert Embeds.embed_src("https://youtu.be/dQw4w9WgXcQ") ==
             "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"

    assert Embeds.embed_src("https://vimeo.com/123456789") ==
             "https://player.vimeo.com/video/123456789"

    assert Embeds.embed_src("https://www.loom.com/share/abcdefabcdefabcdefabcdefabcdefab") ==
             "https://www.loom.com/embed/abcdefabcdefabcdefabcdefabcdefab"

    refute Embeds.embed_src("javascript:alert(1)")
    refute Embeds.embed_src("https://evil.example/watch?v=dQw4w9WgXcQ")
    refute Embeds.embed_src("http://www.youtube.com/watch?v=dQw4w9WgXcQ")
    refute Embeds.embed_src("https://user:pass@www.youtube.com/watch?v=dQw4w9WgXcQ")
    refute Embeds.embed_src("https://www.youtube.com.evil.example/watch?v=dQw4w9WgXcQ")

    assert Embeds.frame_origins() == [
             "https://www.youtube-nocookie.com",
             "https://player.vimeo.com",
             "https://www.loom.com"
           ]
  end

  test "public blocks drop foreign files, missing alt text and unknown embeds", %{
    profile: profile
  } do
    image = "sales_rooms/#{profile.id}/images/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg"
    foreign = "sales_rooms/0/images/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg"

    {:ok, document} =
      Document.put_block(Document.blank(), "hero", %{
        "enabled" => true,
        "headline" => "Klarheit",
        "subline" => "In 45 Minuten",
        "image_path" => image,
        "image_alt" => "Lena im Studio",
        "image_kind" => "portrait"
      })

    {:ok, document} =
      Document.normalize(%{
        "blocks" =>
          Enum.map(document["blocks"], fn
            %{"id" => "gallery"} ->
              %{
                "id" => "gallery",
                "type" => "gallery",
                "enabled" => true,
                "images" => [
                  %{"path" => image, "alt" => "Workshop"},
                  %{"path" => foreign, "alt" => "Fremd"},
                  %{"path" => image, "alt" => ""}
                ]
              }

            other ->
              other
          end)
      })

    {:ok, document} =
      Document.put_block(document, "video", %{
        "enabled" => true,
        "url" => "https://youtu.be/dQw4w9WgXcQ"
      })

    blocks = Document.public_blocks(document, profile.id)
    hero = Enum.find(blocks, &(&1["type"] == "hero"))
    gallery = Enum.find(blocks, &(&1["type"] == "gallery"))
    video = Enum.find(blocks, &(&1["type"] == "video"))

    assert hero["headline"] == "Klarheit"
    assert hero["image_path"] == image
    assert gallery["images"] == [%{"path" => image, "alt" => "Workshop"}]
    assert video["embed_src"] == "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"
    refute video["url"]
  end

  test "an image without a description cannot be saved", %{profile: profile} do
    path = "sales_rooms/#{profile.id}/images/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg"

    assert {:error, :alt_required} =
             Document.put_block(Document.blank(), "hero", %{
               "enabled" => true,
               "headline" => "Hallo",
               "image_path" => path,
               "image_alt" => ""
             })
  end

  test "offer points stop at five" do
    items = for n <- 1..6, do: %{"title" => "Punkt #{n}", "text" => "Text"}

    assert {:error, :too_many_items} =
             Document.put_block(Document.blank(), "offer", %{"enabled" => true, "items" => items})
  end

  test "blocks move up and down and a missing type stays available" do
    {:ok, document} = Document.move(Document.blank(), "cta", :up)
    ids = Enum.map(document["blocks"], & &1["id"])
    assert Enum.at(ids, -2) == "cta"
    assert "hero" in ids
    assert length(ids) == 9
  end

  test "free hides the room and keeps the document", %{user: user, profile: profile} do
    assert {:ok, _saved} = SalesRooms.save(profile, nil, nil, hero_document("Sichtbar"))

    with_config(:tymeslot, plans_enabled: true)
    Plans.invalidate(user.id)
    assert SalesRooms.for_public(profile, nil) == nil

    {:ok, entitlement} =
      Plans.upsert_entitlement(%{
        "data" => %{
          "external_user_id" => "booking:#{user.id}",
          "plan" => "pro",
          "status" => "active"
        },
        "version" => 1
      })

    assert entitlement.plan == "pro"
    Plans.invalidate(user.id)
    assert %{blocks: [%{"headline" => "Sichtbar"}]} = SalesRooms.for_public(profile, nil)

    {:ok, _downgraded} =
      Plans.upsert_entitlement(%{
        "data" => %{
          "external_user_id" => "booking:#{user.id}",
          "plan" => "free",
          "status" => "canceled"
        },
        "version" => 2
      })

    Plans.invalidate(user.id)
    assert SalesRooms.for_public(profile, nil) == nil
    assert {:ok, %{"blocks" => blocks}} = SalesRooms.fetch(profile.id, nil, nil)
    assert Enum.find(blocks, &(&1["id"] == "hero"))["headline"] == "Sichtbar"
  end

  test "an event type replaces the page and can be cleared", %{user: user, profile: profile} do
    event = insert(:meeting_type, user: user, name: "Strategie")
    assert {:ok, _page} = SalesRooms.save(profile, nil, nil, hero_document("Seite"))
    assert {:ok, _event} = SalesRooms.save(profile, nil, event.id, hero_document("Termin"))

    assert %{blocks: [%{"headline" => "Termin"}]} = SalesRooms.for_public(profile, event.id)
    assert %{blocks: [%{"headline" => "Seite"}]} = SalesRooms.for_public(profile, nil)

    assert :ok = SalesRooms.reset_override(profile, nil, event.id)
    assert %{blocks: [%{"headline" => "Seite"}]} = SalesRooms.for_public(profile, event.id)
  end

  test "page views and downloads are counters without a visitor record", %{profile: profile} do
    assert Metrics.record_view(profile.id, nil) == :ok
    assert Metrics.record_view(profile.id, nil) == :ok
    assert Metrics.record_download(profile.id, nil) == :ok
    assert SalesRooms.stats(profile.id, nil) == %{page_views: 2, document_downloads: 1}
  end

  test "uploads accept a real image and a pdf, and refuse html" do
    UploadRoot.isolate("sales-room")
    profile_id = 7

    image_source =
      Path.join(System.tmp_dir!(), "sales-room-#{System.unique_integer([:positive])}.png")

    File.cp!(MediaFixtures.path("gps.png"), image_source)

    assert {:ok, image} = Storage.store(profile_id, :image, %{path: image_source})

    assert image =~ "sales_rooms/7/images/"
    assert String.ends_with?(image, ".png")
    assert Storage.public_url(image) == "/uploads/" <> image

    pdf = Path.join(System.tmp_dir!(), "sales-room-#{System.unique_integer([:positive])}.pdf")
    File.write!(pdf, "%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n")
    assert {:ok, stored, bytes} = Storage.store(profile_id, :document, %{path: pdf})
    assert String.ends_with?(stored, ".pdf")
    assert bytes > 0
    assert Storage.public_url(stored) == nil

    html = Path.join(System.tmp_dir!(), "sales-room-#{System.unique_integer([:positive])}.pdf")
    File.write!(html, "<html><script>alert(1)</script></html>")
    assert {:error, :invalid_pdf} = Storage.store(profile_id, :document, %{path: html})

    huge = Path.join(System.tmp_dir!(), "sales-room-#{System.unique_integer([:positive])}.pdf")
    {:ok, fd} = File.open(huge, [:write])
    :ok = :file.pwrite(fd, Storage.document_max_bytes(), "x")
    :ok = File.close(fd)
    assert {:error, :too_large} = Storage.store(profile_id, :document, %{path: huge})
  end

  defp hero_document(headline) do
    {:ok, document} =
      Document.put_block(Document.blank(), "hero", %{
        "enabled" => true,
        "headline" => headline,
        "subline" => "Neben dem Kalender"
      })

    document
  end
end
