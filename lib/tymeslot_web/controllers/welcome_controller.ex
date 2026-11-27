defmodule TymeslotWeb.WelcomeController do
  @moduledoc """
  Landing address for growth-os-billing links.

  `https://book.scalepoint-ventures.com/welcome?checkout=success` is where
  checkout returns after a payment; the plan page then shows that the
  entitlement is still catching up. A bare `/welcome` is the button in
  billing's trial-started mail and opens the dashboard, so a host on a fresh
  trial is not told that a payment is being activated.
  """

  use TymeslotWeb, :controller

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"checkout" => "success"}) do
    redirect(conn, to: ~p"/dashboard/plan?checkout=success")
  end

  def show(conn, _params) do
    redirect(conn, to: ~p"/dashboard")
  end
end
