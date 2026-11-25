defmodule TymeslotWeb.SalesRoomLiveTest do
  use TymeslotWeb.LiveCase, async: false

  import Tymeslot.ConfigTestHelpers
  import Tymeslot.DashboardTestHelpers

  alias Tymeslot.Plans
  alias Tymeslot.Plans.AccessChecker
  alias Tymeslot.SalesRooms.Blocks

  setup %{conn: conn} do
    with_config(:tymeslot,
      plans_enabled: true,
      feature_access_checker: AccessChecker,
      plans: [trial_days: 14, comped_user_emails: [], oauth_video_providers: []]
    )

    {:ok, conn: conn, user: user, profile: profile} = setup_dashboard_user(%{conn: conn})
    %{conn: conn, user: user, profile: profile}
  end

  test "free sees the blocks and an upgrade note, and cannot save", %{
    conn: conn,
    user: user,
    profile: profile
  } do
    {:ok, view, html} = live(conn, ~p"/dashboard/sales-room")
    assert html =~ "sales-room-upgrade"
    assert html =~ "Hero"
    assert html =~ "One promise, a little proof"
    assert has_element?(view, "[data-testid='sales-room-toggle-hero'][disabled]")
    assert Tymeslot.SalesRooms.get(profile.id, nil, nil) == nil
    assert Plans.effective_plan(user.id) == :free
  end

  test "pro can turn a block on", %{conn: conn, user: user} do
    {:ok, _} =
      Plans.upsert_entitlement(%{
        "data" => %{
          "external_user_id" => "booking:#{user.id}",
          "plan" => "pro",
          "status" => "active"
        },
        "version" => 2
      })

    Plans.invalidate(user.id)
    {:ok, view, html} = live(conn, ~p"/dashboard/sales-room")
    refute html =~ "sales-room-upgrade"

    view |> element("[data-testid='sales-room-toggle-hero']") |> render_click()
    assert render(view) =~ "On"
  end

  test "the public story escapes text and uses the allowlisted embed" do
    blocks =
      Blocks.blank()
      |> Blocks.put_enabled("hero", true)
      |> Blocks.put_content("hero", %{"headline" => "<script>nope</script>", "subline" => "Sub"})
      |> Blocks.put_enabled("video", true)
      |> Blocks.put_content("video", %{"url" => "https://youtu.be/dQw4w9WgXcQ", "title" => "Film"})
      |> Blocks.put_enabled("cta", true)
      |> Blocks.put_content("cta", %{"button_label" => "Termin wählen"})

    html =
      render_component(&TymeslotWeb.SalesRooms.Story.blocks/1,
        room: %{id: 1, blocks: Blocks.presentable(blocks)},
        count?: false,
        calendar_href: "#when-step"
      )

    assert html =~ "Termin wählen"
    assert html =~ "youtube-nocookie.com/embed/dQw4w9WgXcQ"
    refute html =~ "<script>nope</script>"
    assert html =~ "nope"
  end
end
