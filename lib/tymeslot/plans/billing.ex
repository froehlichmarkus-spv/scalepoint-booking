defmodule Tymeslot.Plans.Billing do
  @moduledoc """
  The only door from the dashboard to growth-os-billing.

  Checkout and the customer portal call these functions. Registration,
  cancellation and entitlement reads use the same behaviour,
  `Tymeslot.Plans.BillingClient`. Runtime uses the HTTP client when the
  billing URL and API key are set, and the stub otherwise. Signed entitlement
  events come back only to `POST /webhooks/growth-os-billing`.
  """

  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Plans.BillingClient
  alias Tymeslot.Plans.BillingClient.HTTP
  alias Tymeslot.Plans.ReturnUrls
  alias TymeslotWeb.ErrorHTML

  @spec checkout(map(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def checkout(user, interval, urls \\ %{}) do
    BillingClient.create_checkout(user, interval, urls)
  end

  @spec portal(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def portal(user, return_url) do
    BillingClient.create_portal(user, return_url)
  end

  @spec checkout_urls() :: %{success: String.t(), cancel: String.t()}
  def checkout_urls, do: ReturnUrls.checkout()

  @spec portal_return_url() :: String.t()
  def portal_return_url, do: ReturnUrls.portal()

  @doc "True only while the configured HTTP client gets a 2xx from `/healthz`."
  @spec healthy?() :: boolean()
  def healthy? do
    Application.get_env(:tymeslot, :billing_client) == HTTP and HTTP.health() == :ok
  end

  @doc """
  Sentence shown while growth-os-billing is not connected.

  Always the informal German catalog entry, with the product name and the
  support address.
  """
  @spec unavailable_message() :: String.t()
  def unavailable_message do
    Gettext.with_locale(TymeslotWeb.Gettext, "de", fn ->
      dgettext(
        "plans",
        "BookDesk24 billing is not connected yet. Try again later or write to %{email}.",
        email: ErrorHTML.support_email()
      )
    end)
  end

  @doc """
  Shown when billing answered `/healthz` but this checkout or portal call failed.
  """
  @spec action_failed_message() :: String.t()
  def action_failed_message do
    "Das hat nicht geklappt. Versuch es noch einmal. That didn't work. Try again."
  end

  @doc """
  Shown when a pro-rata charge fails and billing returns `?billing=payment_failed`.
  """
  @spec payment_failed_message() :: String.t()
  def payment_failed_message do
    "Die Zahlung ist nicht durchgegangen. Aktualisiere deine Karte in der Abrechnung. " <>
      "Payment didn't go through. Update your card in billing."
  end
end
