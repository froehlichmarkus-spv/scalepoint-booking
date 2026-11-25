defmodule Tymeslot.Plans.SubscriptionManager do
  @moduledoc """
  Branding answer for the upstream subscription-manager behaviour.

  Checkout and cancellation of the BookDesk24 subscription live in
  growth-os-billing. This module only tells the app when the fixed Free
  badge is required. Pro never shows it.
  """

  @behaviour Tymeslot.Payments.Behaviours.SubscriptionManager

  alias Tymeslot.Plans
  alias Tymeslot.Plans.BillingClient

  @impl true
  def should_show_branding?(user_id) when is_integer(user_id) do
    Plans.enabled?() and Plans.effective_plan(user_id) == :free
  end

  def should_show_branding?(_), do: false

  @impl true
  def create_subscription_checkout(_price_id, _product, _amount, user_id, email, urls, metadata) do
    interval = metadata[:interval] || metadata["interval"] || "month"

    BillingClient.create_checkout(
      %{id: user_id, email: email},
      interval,
      urls
    )
  end

  @impl true
  def handle_checkout_completed(_session), do: {:error, :not_supported}

  @impl true
  def cancel_subscription(_subscription_id, user_id, opts) do
    BillingClient.cancel(user_id, opts)
  end
end
