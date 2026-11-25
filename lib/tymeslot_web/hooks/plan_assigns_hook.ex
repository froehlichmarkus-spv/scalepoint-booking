defmodule TymeslotWeb.Hooks.PlanAssignsHook do
  @moduledoc """
  Overrides the default feature assigns with the host's effective plan and
  publishes usage so the dashboard can disable a create button before submit.
  """

  import Phoenix.Component
  import Phoenix.LiveView, only: [connected?: 1]

  alias Tymeslot.Features
  alias Tymeslot.Plans

  @spec on_mount(:assign_plan, map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:assign_plan, _params, _session, socket) do
    socket =
      if connected?(socket) do
        subscribe(socket)
      else
        socket
      end

    {:cont, assign_plan(socket)}
  end

  @doc "Re-reads the plan after a billing push."
  @spec refresh(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def refresh(socket), do: assign_plan(socket)

  @spec assign_plan(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def assign_plan(socket) do
    user = socket.assigns[:current_user]

    if Plans.enabled?() and match?(%{id: id} when is_integer(id), user) do
      plan = Plans.effective_plan(user.id)
      flags = Plans.features(plan)
      entitlement = Plans.get_entitlement(user.id)

      socket
      |> assign(flags)
      |> assign(:meeting_payments, Features.meeting_payments_allowed?(user.id))
      |> assign(:current_plan, plan)
      |> assign(:plan_status, entitlement && entitlement.status)
      |> assign(:trial_ends_at, entitlement && entitlement.trial_ends_at)
      |> assign(:plan_limits, Plans.limits(plan))
      |> assign(:plan_usage, Plans.usage(user.id))
    else
      socket
      |> assign(:current_plan, nil)
      |> assign(:plan_limits, %{meeting_types: :infinity, calendar_integrations: :infinity})
      |> assign(:plan_usage, %{meeting_types: 0, calendar_integrations: 0})
    end
  end

  defp subscribe(socket) do
    case socket.assigns[:current_user] do
      %{id: id} when is_integer(id) ->
        Phoenix.PubSub.subscribe(Tymeslot.PubSub, "plans:#{id}")
        socket

      _ ->
        socket
    end
  end
end
