defmodule Tymeslot.Plans.Billing do
  @moduledoc """
  The only door from the dashboard to growth-os-billing.

  Checkout and the customer portal call these functions. Registration,
  cancellation and entitlement reads use the same behaviour,
  `Tymeslot.Plans.BillingClient`. The configured implementation is the stub,
  which does not call the network. Signed entitlement events, once the
  central service sends them, come back only to
  `POST /webhooks/growth-os-billing`.
  """

  alias Tymeslot.Plans.BillingClient
  alias TymeslotWeb.ErrorHTML

  @spec checkout(map(), String.t(), map()) :: {:ok, %{url: String.t()}} | {:error, term()}
  def checkout(user, interval, urls \\ %{}) do
    BillingClient.create_checkout(user, interval, urls)
  end

  @spec portal(map(), String.t()) :: {:ok, %{url: String.t()}} | {:error, term()}
  def portal(user, return_url) do
    BillingClient.create_portal(user, return_url)
  end

  @doc """
  Sentence shown while growth-os-billing is not connected.

  Informal German, with the product name and the support address. It is not
  a gettext entry: the catalogs on this branch stay identical to main.
  """
  @spec unavailable_message() :: String.t()
  def unavailable_message do
    "Die Abrechnung von BookDesk24 ist noch nicht da. Versuch es später noch einmal oder schreib an #{ErrorHTML.support_email()}."
  end
end
