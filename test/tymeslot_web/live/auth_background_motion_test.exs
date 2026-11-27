defmodule TymeslotWeb.Live.AuthBackgroundMotionTest do
  @moduledoc """
  The auth pages no longer autoplay a background video. WCAG 2.2 SC 2.2.2
  is met by not starting motion the visitor cannot stop.
  """

  use TymeslotWeb.LiveCase, async: true

  @moduletag :auth
  @moduletag :live

  import Phoenix.LiveViewTest

  defp document(conn, path) do
    {:ok, _view, html} = live(conn, path)
    Floki.parse_document!(html)
  end

  describe "login page" do
    test "does not autoplay a background video", %{conn: conn} do
      doc = document(conn, ~p"/auth/login")

      assert Floki.find(doc, "#auth-video-container video") == []
    end
  end

  describe "signup page" do
    test "does not autoplay a background video", %{conn: conn} do
      doc = document(conn, ~p"/auth/signup")

      assert Floki.find(doc, "#auth-video-container video") == []
    end
  end
end
