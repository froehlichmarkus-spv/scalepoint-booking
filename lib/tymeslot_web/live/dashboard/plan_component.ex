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
              <th>
                Team <span class="gos-plan-muted">{dgettext("plans", "Coming soon")}</span>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{label, free, pro, team} <- @rows}>
              <td>{label}</td>
              <td>{free}</td>
              <td>{pro}</td>
              <td>{team}</td>
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
    soon = dgettext("plans", "Coming soon")
    included = dgettext("plans", "Included")
    unlimited = dgettext("plans", "Unlimited")

    quotas = [
      {dgettext("plans", "Event types"), "1", unlimited, soon},
      {dgettext("plans", "Calendars"), "1", unlimited, soon},
      {dgettext("plans", "Google Calendar"), dgettext("plans", "One"), unlimited, soon},
      {dgettext("plans", "Google Meet, Zoom, Teams"), "—", included, soon},
      {dgettext("plans", "Group, polls, recurring"), "—", included, soon},
      {dgettext("plans", "Payments, webhooks, reminders"), "—", included, soon}
    ]

    quotas ++
      Enum.map(Plans.catalog(), fn row ->
        {catalog_label(row.key), cell(row.free), cell(row.pro), cell(row.team)}
      end)
  end

  defp cell(true), do: dgettext("plans", "Included")
  defp cell(false), do: "—"
  defp cell(:coming_soon), do: dgettext("plans", "Coming soon")

  defp catalog_label(:standard_booking), do: dgettext("plans", "Online booking")
  defp catalog_label(:short_link), do: dgettext("plans", "Short booking link")
  defp catalog_label(:profile_intro), do: dgettext("plans", "Profile photo and short text")
  defp catalog_label(:calendar), do: dgettext("plans", "Calendar")
  defp catalog_label(:powered_by_badge), do: dgettext("plans", "Powered by BookDesk24")
  defp catalog_label(:sales_room), do: dgettext("plans", "Sales room")
  defp catalog_label(:sales_room_media), do: dgettext("plans", "Photos, video, PDFs and quotes")
  defp catalog_label(:custom_logo), do: dgettext("plans", "Your logo")
  defp catalog_label(:custom_accent), do: dgettext("plans", "Your accent colour")
  defp catalog_label(_), do: dgettext("plans", "Feature")

  defp success_url, do: "/dashboard/plan?checkout=success"
  defp cancel_url, do: "/dashboard/plan?checkout=cancel"
end
