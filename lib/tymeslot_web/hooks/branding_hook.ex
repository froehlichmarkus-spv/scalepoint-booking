defmodule TymeslotWeb.Hooks.BrandingHook do
  @moduledoc """
  Sets `should_show_branding` when the organiser is already on the socket.

  The organiser is often resolved after `on_mount`, so
  `TymeslotWeb.Themes.Shared.SchedulingPage` also asks
  `Tymeslot.Payments.show_branding?/1` when this assign is still unset.
  """

  import Phoenix.Component

  alias Tymeslot.Payments

  @spec on_mount(:default, map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, _session, socket) do
    user_id = socket.assigns[:organizer_user_id]

    socket =
      if is_integer(user_id) do
        assign(socket, :should_show_branding, Payments.show_branding?(user_id))
      else
        socket
      end

    {:cont, socket}
  end
end
