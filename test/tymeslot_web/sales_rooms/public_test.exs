defmodule TymeslotWeb.SalesRooms.PublicTest do
  use Tymeslot.DataCase, async: true

  @moduletag :bookings

  import Phoenix.LiveViewTest

  alias TymeslotWeb.SalesRooms.Public

  test "renders the story and the button that leads to the calendar" do
    html =
      render_component(&Public.story/1,
        blocks: [
          %{
            "type" => "hero",
            "headline" => "Klarheit für Ihre Zahlen",
            "subline" => "In einem Gespräch.",
            "image_path" => nil,
            "image_alt" => nil,
            "image_kind" => "portrait"
          },
          %{
            "type" => "cta",
            "headline" => "Lassen Sie uns sprechen",
            "text" => nil,
            "button" => "Termin wählen"
          }
        ],
        profile: %{id: 1, full_name: "Lena Hartmann"},
        locale: "de",
        preview: true
      )

    assert html =~ "Klarheit für Ihre Zahlen"
    assert html =~ "Termin wählen"
    assert html =~ "host-room-pick"
    assert html =~ "#host-room-book"
    refute html =~ "Tymeslot"
    refute html =~ "tymeslot"
  end

  test "an embed is only the allowlisted iframe" do
    html =
      render_component(&Public.story/1,
        blocks: [
          %{
            "type" => "video",
            "embed_src" => "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
            "title" => "Rundgang"
          }
        ],
        profile: nil,
        locale: "en",
        preview: false
      )

    assert html =~ "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"
    refute html =~ "<script"
  end
end
