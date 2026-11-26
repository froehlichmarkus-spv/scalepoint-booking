defmodule Tymeslot.Plans.BillingClient.Stub do
  @moduledoc """
  Stand-in for growth-os-billing.

  Checkout, the portal, entitlement reads, registration and cancellation all
  answer locally. Nothing on this module opens a socket. Runtime selects
  `Tymeslot.Plans.BillingClient.HTTP` when `GROWTH_OS_BILLING_URL` and
  `GROWTH_OS_BILLING_API_KEY` are both set.
  """

  @behaviour Tymeslot.Plans.BillingClient

  @impl Tymeslot.Plans.BillingClient
  def create_checkout(_user, _interval, _urls), do: {:error, :unavailable}

  @impl Tymeslot.Plans.BillingClient
  def create_portal(_user, _return_url), do: {:error, :unavailable}

  @impl Tymeslot.Plans.BillingClient
  def get_entitlement(_user_id), do: {:error, :unavailable}

  @impl Tymeslot.Plans.BillingClient
  def register_account(_user), do: :ok

  @impl Tymeslot.Plans.BillingClient
  def cancel(_user_id, _opts), do: :ok
end
