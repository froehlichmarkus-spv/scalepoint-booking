defmodule TymeslotWeb.WelcomeController do
  @moduledoc """
  Where checkout sends the host after a successful payment.

  The address is `https://book.scalepoint-ventures.com/welcome`. From there
  the plan page shows that the entitlement is still catching up.
  """

  use TymeslotWeb, :controller

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    redirect(conn, to: ~p"/dashboard/plan?checkout=success")
  end
end
