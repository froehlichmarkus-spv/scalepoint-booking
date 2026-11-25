defmodule Tymeslot.Plans.BillingClient do
  @moduledoc """
  HTTP client for growth-os-billing.

  The app never creates Stripe subscriptions itself. Subscription webhooks
  stay on the billing service and are pushed back here, signed, to
  `/webhooks/growth-os-billing` — not to `/webhooks/stripe`.
  """

  @callback create_checkout(map(), String.t(), map()) ::
              {:ok, %{url: String.t()}} | {:error, term()}
  @callback create_portal(map(), String.t()) :: {:ok, %{url: String.t()}} | {:error, term()}
  @callback get_entitlement(integer()) :: {:ok, map()} | {:error, term()}
  @callback register_account(map()) :: :ok | {:error, term()}
  @callback cancel(integer(), keyword() | map()) :: :ok | {:error, term()}

  @spec create_checkout(term(), term(), term()) :: term()
  def create_checkout(user, interval, urls \\ %{}),
    do: impl().create_checkout(user, interval, urls)

  @spec create_portal(term(), term()) :: term()
  def create_portal(user, return_url), do: impl().create_portal(user, return_url)
  @spec get_entitlement(term()) :: term()
  def get_entitlement(user_id), do: impl().get_entitlement(user_id)
  @spec register_account(term()) :: term()
  def register_account(user), do: impl().register_account(user)
  @spec cancel(term(), term()) :: term()
  def cancel(user_id, opts \\ []), do: impl().cancel(user_id, opts)

  defp impl do
    Application.get_env(:tymeslot, :billing_client, Tymeslot.Plans.BillingClient.HTTP)
  end
end
