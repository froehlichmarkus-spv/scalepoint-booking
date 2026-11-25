defmodule Tymeslot.Plans.Limits do
  @moduledoc """
  Quantity limits for event types and calendar connections.

  Call `check_quota/2` inside the insert transaction. It locks the user row
  so two concurrent creates cannot both pass a count of zero. Reconnects
  update an existing row and do not come through here. Existing calendars
  stay active after a downgrade; only adding another one is refused.
  """

  alias Tymeslot.Plans
  alias Tymeslot.Plans.Queries

  @resources [:meeting_types, :calendar_integrations]

  @doc "` :ok` when the host may add one more of `resource`."
  @spec check_quota(integer(), :meeting_types | :calendar_integrations) ::
          :ok | {:error, :quota_exceeded}
  def check_quota(user_id, resource) when is_integer(user_id) and resource in @resources do
    if Plans.enabled?() do
      lock_user(user_id)
      limit = Plans.limits(Plans.effective_plan(user_id))[resource]
      used = Plans.usage(user_id)[resource]

      if limit == :infinity or used < limit, do: :ok, else: {:error, :quota_exceeded}
    else
      :ok
    end
  end

  def check_quota(_user_id, _resource), do: :ok

  @doc "Free may use every calendar provider unless `free_calendar_providers` is set."
  @spec ensure_calendar_provider(integer(), term()) :: :ok | {:error, :pro_required}
  def ensure_calendar_provider(user_id, provider) when is_integer(user_id) do
    allowed = plans(:free_calendar_providers)

    cond do
      not Plans.enabled?() -> :ok
      Plans.effective_plan(user_id) == :pro -> :ok
      is_nil(allowed) -> :ok
      to_string(provider) in Enum.map(List.wrap(allowed), &to_string/1) -> :ok
      true -> {:error, :pro_required}
    end
  end

  def ensure_calendar_provider(_unused32, _unused35), do: :ok

  @spec at_quota?(map() | nil, map() | nil, atom()) :: boolean()
  def at_quota?(limits, usage, resource) when is_map(limits) and is_map(usage) do
    case Map.get(limits, resource) do
      max when is_integer(max) -> Map.get(usage, resource, 0) >= max
      _unused7 -> false
    end
  end

  def at_quota?(_unused17, _unused20, _unused23), do: false

  defp lock_user(user_id) do
    Queries.lock_user(user_id)
  end

  defp plans(key) do
    Keyword.get(Application.get_env(:tymeslot, :plans, []), key)
  end
end
