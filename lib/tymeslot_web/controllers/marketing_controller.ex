defmodule TymeslotWeb.MarketingController do
  @moduledoc """
  The public BookDesk24 page: the v2.8 imagery recipe (hero, mood, one dark
  band, photo CTA). It is not the signed-in product.
  """
  use TymeslotWeb, :controller

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    conn
    |> put_layout(false)
    |> put_root_layout(false)
    |> render(:show)
  end
end
