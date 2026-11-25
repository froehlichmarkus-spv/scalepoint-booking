defmodule Tymeslot.Plans.UserRegisteredHook do
  @moduledoc """
  Opens the local 14-day Pro trial, then tells billing. The trial is local
  first so the host has Pro even when billing is down. Billing's later push
  is authoritative. The upstream worker retries `{:error, _}`.
  """

  @behaviour Tymeslot.Auth.Behaviours.UserRegisteredHook

  alias Tymeslot.Auth.UserSchema
  alias Tymeslot.Plans
  alias Tymeslot.Plans.BillingClient
  alias Tymeslot.Plans.Queries

  @impl Tymeslot.Auth.Behaviours.UserRegisteredHook
  def on_user_registered(user_id, _metadata) when is_integer(user_id) do
    with {:ok, _unused16} <- Plans.start_local_trial(user_id),
         %UserSchema{} = user <- Queries.get_user(user_id),
         :ok <- BillingClient.register_account(user) do
      :ok
    else
      nil -> :ok
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end
end
