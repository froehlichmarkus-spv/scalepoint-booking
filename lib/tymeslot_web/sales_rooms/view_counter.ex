defmodule TymeslotWeb.SalesRooms.ViewCounter do
  @moduledoc """
  Counts one page view per connected visit. The dashboard preview passes
  `count?: false`. Nothing is sent to a third party.
  """

  use TymeslotWeb, :live_component

  alias Tymeslot.SalesRooms

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if connected?(socket) and assigns[:count?] != false and socket.assigns[:counted] != true do
        SalesRooms.record_view(%{id: assigns.room_id})
        assign(socket, :counted, true)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <span class="sr-view-counter" hidden></span>
    """
  end
end
