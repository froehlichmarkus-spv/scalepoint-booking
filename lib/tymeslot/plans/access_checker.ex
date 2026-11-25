defmodule Tymeslot.Plans.AccessChecker do
  @moduledoc """
  Plan-aware `Tymeslot.Features.CheckerBehaviour`.

  Unknown feature atoms stay allowed so a new upstream feature is not locked
  by accident. `:meeting_payments` uses
  `AccountCurrency.charges_enabled_for_user?/1` and never
  `MeetingPayments.accepting_payments?/1`, which calls back into this checker.
  """

  @behaviour Tymeslot.Features.CheckerBehaviour

  alias Tymeslot.MeetingPayments.AccountCurrency
  alias Tymeslot.Plans

  @impl Tymeslot.Features.CheckerBehaviour
  def check_access(user_id, :meeting_payments) when is_integer(user_id) do
    cond do
      not Application.get_env(:tymeslot, :meeting_payments_enabled, false) ->
        {:error, :feature_disabled}

      Plans.effective_plan(user_id) != :pro ->
        {:error, :pro_required}

      not AccountCurrency.charges_enabled_for_user?(user_id) ->
        {:error, :stripe_required}

      true ->
        :ok
    end
  end

  def check_access(user_id, feature) when is_integer(user_id) and is_atom(feature) do
    if Plans.feature?(Plans.effective_plan(user_id), feature) do
      :ok
    else
      {:error, :pro_required}
    end
  end

  def check_access(_user_id, _feature), do: {:error, :feature_access_checker_failed}
end
