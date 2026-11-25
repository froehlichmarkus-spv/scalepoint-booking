defmodule TymeslotWeb.Dashboard.SalesRoomComponentTest do
  use TymeslotWeb.LiveCase, async: true

  @moduletag :dashboard

  import Tymeslot.DashboardTestHelpers

  alias Tymeslot.SalesRooms

  setup :setup_dashboard_user_with_theme

  test "the editor saves a headline and reorders blocks", %{conn: conn, profile: profile} do
    {:ok, view, html} = live(conn, ~p"/dashboard/sales-room")

    assert html =~ "Sales room"
    refute html =~ "data-testid=\"sales-room-upgrade\""

    view |> element("[data-testid='sales-room-toggle']") |> render_click()

    view
    |> form("#sales-room-form", %{
      "headline" => "Klarheit für Ihre Zahlen",
      "subline" => "Ein Gespräch, kein Pitch.",
      "image_alt" => "",
      "image_kind" => "portrait"
    })
    |> render_submit()

    {:ok, document} = SalesRooms.fetch(profile.id, nil, nil)
    hero = Enum.find(document["blocks"], &(&1["id"] == "hero"))
    assert hero["headline"] == "Klarheit für Ihre Zahlen"
    assert hero["enabled"]

    view |> element("[data-testid='sales-room-up-cta']") |> render_click()
    {:ok, moved} = SalesRooms.fetch(profile.id, nil, nil)
    assert Enum.at(moved["blocks"], -2)["id"] == "cta"
  end

  test "a switched-off block stays in the document", %{conn: conn, profile: profile} do
    {:ok, view, _html} = live(conn, ~p"/dashboard/sales-room")

    view |> element("[data-testid='sales-room-toggle']") |> render_click()

    view
    |> form("#sales-room-form", %{
      "headline" => "Bleibt",
      "subline" => "",
      "image_alt" => "",
      "image_kind" => "portrait"
    })
    |> render_submit()

    view |> element("[data-testid='sales-room-toggle']") |> render_click()

    {:ok, document} = SalesRooms.fetch(profile.id, nil, nil)
    hero = Enum.find(document["blocks"], &(&1["id"] == "hero"))
    assert hero["headline"] == "Bleibt"
    refute hero["enabled"]
  end
end
