defmodule TymeslotWeb.Dashboard.PlanComponent do
  @moduledoc """
  Plan & billing page. Prices are the configured display prices, not a live
  Stripe read. Checkout and the customer portal are URLs from growth-os-billing.
  """

  use TymeslotWeb, :live_component
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Plans
  alias Tymeslot.Plans.BillingClient
  alias TymeslotWeb.Live.Shared.Flash

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if connected?(socket) and checkout_success?(assigns) and
           socket.assigns[:resync_armed] != true do
        Process.send_after(self(), {:plan_resync, assigns.id}, 10_000)
        assign(socket, :resync_armed, true)
      else
        socket
      end

    {:ok, load(socket)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("checkout", %{"interval" => interval}, socket) do
    user = socket.assigns.current_user
    urls = %{success: success_url(), cancel: cancel_url()}

    case BillingClient.create_checkout(user, interval, urls) do
      {:ok, %{url: url}} ->
        {:noreply, redirect(socket, external: url)}

      {:error, _reason} ->
        Flash.error(dgettext("plans", "Billing is unavailable. Try again in a moment."))
        {:noreply, socket}
    end
  end

  def handle_event("portal", _params, socket) do
    case BillingClient.create_portal(socket.assigns.current_user, success_url()) do
      {:ok, %{url: url}} ->
        {:noreply, redirect(socket, external: url)}

      {:error, _reason} ->
        Flash.error(dgettext("plans", "Billing is unavailable. Try again in a moment."))
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.dashboard_page icon="hero-credit-card" title={dgettext("plans", "Plan & billing")}>
        <div class="gos-plan">
          <section class="gos-plan-card">
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
      </.dashboard_page>
    </div>
    """
  end

  defp load(socket) do
    user = socket.assigns.current_user
    prices = Plans.display_prices()

    socket
    |> assign(:plan, Plans.effective_plan(user.id))
    |> assign(:entitlement, Plans.get_entitlement(user.id))
    |> assign(:limits, Plans.limits(Plans.effective_plan(user.id)))
    |> assign(:usage, Plans.usage(user.id))
    |> assign(:prices, prices)
    |> assign(:checkout_success, checkout_success?(socket.assigns))
    |> assign(:rows, comparison_rows())
  end

  defp checkout_success?(assigns) do
    params = assigns[:params] || %{}
    checkout_flag(params) == "success"
  end

  defp plan_line(%{
         plan: :pro,
         entitlement: %{status: "trialing", trial_ends_at: %DateTime{} = ends}
       }) do
    dgettext("plans", "Pro trial until %{date}", date: Calendar.strftime(ends, "%Y-%m-%d"))
  end

  defp plan_line(%{plan: :pro}), do: dgettext("plans", "You are on Pro.")
  defp plan_line(_unused18), do: dgettext("plans", "You are on Free.")

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

  defp checkout_flag(params) when is_list(params), do: Keyword.get(params, :checkout)

  defp checkout_flag(params) when is_map(params) do
    case Map.fetch(params, :checkout) do
      {:ok, value} -> value
      :error -> Map.get(params, "checkout")
    end
  end

  defp checkout_flag(_params), do: nil

  defp success_url, do: "/dashboard/plan?checkout=success"
  defp cancel_url, do: "/dashboard/plan?checkout=cancel"
end
