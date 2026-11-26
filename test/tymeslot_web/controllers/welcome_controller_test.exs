defmodule TymeslotWeb.WelcomeControllerTest do
  use TymeslotWeb.ConnCase, async: false

  @moduletag :payments

  import Tymeslot.AuthTestHelpers, only: [log_in_user: 2]
  import Tymeslot.Factory

  test "checkout success lands on the plan page", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> setup_session()
      |> log_in_user(user)
      |> get("/welcome")

    assert redirected_to(conn) == "/dashboard/plan?checkout=success"
  end
end
