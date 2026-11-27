defmodule TymeslotWeb.MarketingControllerTest do
  use TymeslotWeb.ConnCase, async: true

  test "the public page shows the hero, the caption, and the real fee", %{conn: conn} do
    conn = get(conn, ~p"/bookdesk24")
    body = html_response(conn, 200)

    assert body =~ "booking-hero.jpg"
    assert body =~ "Illustrative image, generated for ScalePoint. Not a customer."
    assert body =~ "0%"
    assert body =~ "data-gos-count"
    assert body =~ ~s(fetchpriority="high")
    refute body =~ ~s(fetchpriority="high" data-gos-reveal)
  end
end
