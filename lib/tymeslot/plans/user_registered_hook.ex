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

  @statuses ~w(none trialing active past_due canceled)

  @impl Tymeslot.Auth.Behaviours.UserRegisteredHook
  def on_user_registered(user_id, metadata) when is_integer(user_id) do
    with {:ok, _trial} <- Plans.start_local_trial(user_id),
         %UserSchema{} = user <- Queries.get_user(user_id) do
      register(user, metadata || %{})
    else
      nil -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp register(user, metadata) do
    attrs = %{
      id: user.id,
      email: user.email,
      name: user.name,
      locale: user.locale,
      organisation_id: organisation_id(metadata)
    }

    case BillingClient.register_account(attrs) do
      :ok ->
        :ok

      {:ok, body} ->
        apply_registration(user.id, body)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_registration(user_id, body) when is_map(body) do
    data = registration_data(user_id, body)

    if data["plan"] in ["free", "pro"] and data["status"] in @statuses do
      case Plans.upsert_entitlement(%{"data" => data, "version" => version_of(body)}) do
        {:ok, _saved} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      Plans.store_billing_account_ref(user_id, data["billing_account_ref"])
    end
  end

  defp apply_registration(_user_id, _body), do: :ok

  defp registration_data(user_id, body) do
    raw = field(body, :data)
    data = if is_map(raw), do: stringify(raw), else: %{}
    account_id = field(body, :account_id)

    data =
      if is_binary(account_id) and account_id != "" and blank?(data["billing_account_ref"]) do
        Map.put(data, "billing_account_ref", account_id)
      else
        data
      end

    if is_binary(data["external_user_id"]) and data["external_user_id"] != "" do
      data
    else
      Map.put(data, "external_user_id", Plans.external_user_id(user_id))
    end
  end

  defp version_of(body) do
    case field(body, :version) do
      n when is_integer(n) and n >= 0 ->
        n

      n when is_binary(n) ->
        case Integer.parse(n) do
          {parsed, ""} when parsed >= 0 -> parsed
          _invalid -> 0
        end

      _missing ->
        0
    end
  end

  defp organisation_id(metadata) when is_map(metadata) do
    field(metadata, :organisation_id) || field(metadata, :organization_id)
  end

  defp organisation_id(_metadata), do: nil

  defp stringify(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp blank?(value), do: value in [nil, ""]
end
