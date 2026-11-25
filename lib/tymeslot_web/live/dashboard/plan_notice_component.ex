defmodule TymeslotWeb.Dashboard.PlanNoticeComponent do
  @moduledoc """
  Dashboard banner for a trial ending within three days, a past-due plan, or
  more calendars than Free includes. Calendars are not disconnected.
  """

  use TymeslotWeb, :live_component
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Plans

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    user = assigns.current_user
    {:ok, socket |> assign(assigns) |> assign(:message, message(user.id))}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <p :if={@message} class="gos-plan-notice" data-testid="plan-notice">{@message}</p>
    </div>
    """
  end

  defp message(user_id) do
    if Plans.enabled?() do
      entitlement = Plans.get_entitlement(user_id)
      usage = Plans.usage(user_id)
      plan = Plans.effective_plan(user_id)

      cond do
        entitlement && entitlement.status == "past_due" ->
          dgettext("plans", "A payment is past due. Update billing to keep Pro.")

        entitlement && entitlement.status == "trialing" && ending_soon?(entitlement.trial_ends_at) ->
          dgettext("plans", "Your Pro trial ends within 3 days.")

        plan == :free and usage.calendar_integrations > 1 ->
          dgettext(
            "plans",
            "You are using %{count} of 1 calendars. Upgrade or remove the extra ones. Existing calendars still block double bookings.",
            count: usage.calendar_integrations
          )

        plan == :free and usage.meeting_types > 1 ->
          dgettext(
            "plans",
            "Only your oldest bookable event type is public. The others are paused, not deleted."
          )

        true ->
          nil
      end
    end
  end

  defp ending_soon?(%DateTime{} = ends) do
    DateTime.diff(ends, DateTime.utc_now(), :second) in 0..(3 * 24 * 3600)
  end

  defp ending_soon?(_unused21), do: false
end
