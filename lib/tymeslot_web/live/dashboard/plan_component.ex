defmodule TymeslotWeb.Dashboard.PlanComponent do
  @moduledoc """
  Plan & billing page. Prices are the configured display prices, not a live
  Stripe read. Checkout and the customer portal are URLs from growth-os-billing.
  """

  use TymeslotWeb, :live_component
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Plans
  alias Tymeslot.Plans.BillingClient
  alias Tymeslot.Plans.Workers.EntitlementResync

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if connected?(socket) and checkout_success?(assigns) and
           socket.assigns[:resync_armed] != true do
        Process.send_after(self(), :plan_resync, 10_000)
        assign(socket, :resync_armed, true)
      else
        socket
      end

    {:ok, load(socket)}
  end

  def handle_info(:plan_resync, socket) do
    _ = EntitlementResync.enqueue(socket.assigns.current_user.id)
    {:noreply, load(socket)}
  end

  @impl true
  def handle_event("checkout", %{"interval" => interval}, socket) do
    user = socket.assigns.current_user
    urls = %{success: success_url(), cancel: cancel_url()}

    case BillingClient.create_checkout(user, interval, urls) do
      {:ok, %{url: url}} ->
        {:noreply, redirect(socket, external: url)}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("plans", "Billing is unavailable. Try again in a moment.")
         )}
    end
  end

  def handle_event("portal", _params, socket) do
    case BillingClient.create_portal(socket.assigns.current_user, success_url()) do
      {:ok, %{url: url}} ->
        {:noreply, redirect(socket, external: url)}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("plans", "Billing is unavailable. Try again in a moment.")
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="gos-plan" id={@id}>
      <section :if={@trial} class="gos-plan-card gos-trial" data-testid="pro-trial">
        <h2>{dgettext("plans", "Pro trial")}</h2>
        <p class="gos-plan-muted">
          {dgettext("plans", "%{days} days left. Full Pro access until %{date}.",
            days: elem(@trial, 0),
            date: elem(@trial, 1)
          )}
        </p>
        <p class="gos-plan-muted">
          {dgettext(
            "plans",
            "When the trial ends the workspace returns to Free. Bookings stay. Extra event types pause, and the BookDesk24 badge comes back."
          )}
        </p>
      </section>
      <section :if={@downgraded} class="gos-plan-card gos-downgrade" data-testid="pro-downgrade">
        <h2>{dgettext("plans", "Back on Free")}</h2>
        <p>
          {dgettext(
            "plans",
            "Pro has ended. Your bookings are still here. Extra event types are paused, not deleted. Choose Pro to open them again."
          )}
        </p>
      </section>
      <section class="gos-plan-card">
        <h2>{dgettext("plans", "Plan & billing")}</h2>
        <p class="gos-plan-muted">{plan_line(assigns)}</p>
        <p :if={@checkout_success} class="gos-plan-muted" data-testid="checkout-pending">
          {dgettext("plans", "Activating your plan…")}
        </p>
        <p class="gos-plan-muted">
          {dgettext("plans", "Event types")}: {usage(@usage, :meeting_types, @limits)} · {dgettext(
            "plans",
            "Calendars"
          )}: {usage(@usage, :calendar_integrations, @limits)}
        </p>
        <div class="mt-4 flex flex-wrap gap-2">
          <button
            type="button"
            class="action-button action-button--primary"
            phx-click="checkout"
            phx-value-interval="month"
            phx-target={@myself}
          >
            {dgettext("plans", "Pro monthly – %{price}", price: @prices.monthly.amount)}
          </button>
          <button
            type="button"
            class="action-button action-button--primary"
            phx-click="checkout"
            phx-value-interval="year"
            phx-target={@myself}
          >
            {dgettext("plans", "Pro yearly – %{price}", price: @prices.yearly.amount)}
            <span :if={@prices.yearly[:note]}>({@prices.yearly.note})</span>
          </button>
          <button
            type="button"
            class="action-button action-button--secondary"
            phx-click="portal"
            phx-target={@myself}
          >
            {dgettext("plans", "Manage billing")}
          </button>
        </div>
      </section>
      <section class="gos-plan-card">
        <table class="gos-plan-table">
          <thead>
            <tr>
              <th>{dgettext("plans", "Feature")}</th>
              <th>Free</th>
              <th>Pro</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{label, free, pro} <- @rows}>
              <td>{label}</td>
              <td>{free}</td>
              <td>{pro}</td>
            </tr>
          </tbody>
        </table>
        <p class="gos-plan-muted mt-3">
          {dgettext(
            "plans",
            "Prices are net. VAT IDs for reverse charge are collected by billing. No Stripe Tax."
          )}
        </p>
      </section>
    </div>
    """
  end

  defp load(socket) do
    user = socket.assigns.current_user
    prices = Plans.display_prices()

    plan = Plans.effective_plan(user.id)
    entitlement = Plans.get_entitlement(user.id)

    socket
    |> assign(:plan, plan)
    |> assign(:entitlement, entitlement)
    |> assign(:limits, Plans.limits(plan))
    |> assign(:usage, Plans.usage(user.id))
    |> assign(:prices, prices)
    |> assign(:checkout_success, checkout_success?(socket.assigns))
    |> assign(:rows, comparison_rows())
    |> assign(:trial, trial_banner(entitlement))
    |> assign(:downgraded, downgraded?(entitlement, plan))
  end

  defp trial_banner(%{status: "trialing", trial_ends_at: %DateTime{} = ends}) do
    days = max(div(DateTime.diff(ends, DateTime.utc_now(), :second), 86_400), 0)
    {days, Calendar.strftime(ends, "%Y-%m-%d")}
  end

  defp trial_banner(_), do: nil

  defp downgraded?(%{status: status}, :free)
       when status in ["canceled", "unpaid", "incomplete_expired"],
       do: true

  defp downgraded?(_, _), do: false

  defp checkout_success?(assigns) do
    params = assigns[:params] || %{}
    params["checkout"] == "success" or params[:checkout] == "success"
  end

  defp plan_line(%{
         plan: :pro,
         entitlement: %{status: "trialing", trial_ends_at: %DateTime{} = ends}
       }) do
    dgettext("plans", "Pro trial until %{date}", date: Calendar.strftime(ends, "%Y-%m-%d"))
  end

  defp plan_line(%{plan: :pro}), do: dgettext("plans", "You are on Pro.")
  defp plan_line(_), do: dgettext("plans", "You are on Free.")

  defp usage(usage, key, limits) do
    cap = limits[key]
    cap = if cap == :infinity, do: "∞", else: cap
    "#{usage[key]}/#{cap}"
  end

  defp comparison_rows do
    [
      {dgettext("plans", "Event types"), "1", dgettext("plans", "Unlimited")},
      {dgettext("plans", "Calendars"), "1", dgettext("plans", "Unlimited")},
      {dgettext("plans", "Google Calendar"), dgettext("plans", "One"),
       dgettext("plans", "Unlimited")},
      {dgettext("plans", "Google Meet, Zoom, Teams"), "—", dgettext("plans", "Included")},
      {dgettext("plans", "Group, polls, recurring"), "—", dgettext("plans", "Included")},
      {dgettext("plans", "Payments, webhooks, reminders"), "—", dgettext("plans", "Included")},
      {dgettext("plans", "Powered by BookDesk24"), dgettext("plans", "Always"),
       dgettext("plans", "Hidden")},
      {dgettext("plans", "Your logo and accent"), "—", dgettext("plans", "On your booking page")}
    ]
  end

  defp success_url, do: "/dashboard/plan?checkout=success"
  defp cancel_url, do: "/dashboard/plan?checkout=cancel"
end
