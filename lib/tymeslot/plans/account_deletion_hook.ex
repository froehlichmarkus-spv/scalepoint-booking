defmodule Tymeslot.Plans.AccountDeletionHook do
  @moduledoc """
  Cancels the BookDesk24 subscription before the account is deleted.

  A billing error aborts the deletion so a paying subscription is not left
  behind. A 404 (no billing account) is success.
  """

  @behaviour Tymeslot.Auth.Behaviours.AccountDeletionHook

  alias Tymeslot.Plans
  alias Tymeslot.Plans.BillingClient

  @impl true
  def on_deletion_requested(_user_id, _feedback), do: :ok

  @impl true
  def on_deletion_restored(_user_id), do: :ok

  @impl true
  def on_account_deletion(user_id) when is_integer(user_id) do
    BillingClient.cancel(user_id, reason: "account_deleted", at_period_end: false)
  end

  @impl true
  def purge_protected_user_ids, do: {:ok, Plans.protected_user_ids()}
end
