defmodule Tymeslot.Plans.PlanAccess do
  @moduledoc """
  Downgrade pause for meeting types.

  On Free, only the oldest active type that does not depend on a Pro-only
  video provider stays publicly bookable. Nothing is deleted. Paid and group
  types are already paused by `PaymentAccess` and `GroupAccess`. Calendars
  are not paused: they keep blocking conflicts so a guest is not double-booked.
  """

  import Ecto.Query, warn: false

  alias Tymeslot.MeetingTypes.MeetingTypeQueries
  alias Tymeslot.Plans
  alias Tymeslot.Repo

  @doc "Drops paused types from a public list. A no-op while plans are off."
  @spec reject_paused([map()]) :: [map()]
  def reject_paused(meeting_types) when is_list(meeting_types) do
    if Plans.enabled?() and meeting_types != [] do
      paused =
        meeting_types
        |> Enum.map(& &1.user_id)
        |> Enum.uniq()
        |> Map.new(fn user_id -> {user_id, paused_ids(user_id)} end)

      Enum.reject(meeting_types, fn type ->
        MapSet.member?(Map.get(paused, type.user_id, MapSet.new()), type.id)
      end)
    else
      meeting_types
    end
  end

  @doc "True when this active type is not the one Free still offers."
  @spec paused?(map()) :: boolean()
  def paused?(%{id: id, user_id: user_id}) when is_integer(id) and is_integer(user_id) do
    Plans.enabled?() and Plans.effective_plan(user_id) == :free and
      MapSet.member?(paused_ids(user_id), id)
  end

  def paused?(_), do: false

  @doc "Hard stop for a booking submit that still has the page open."
  @spec ensure_bookable(map()) :: :ok | {:error, :plan_paused}
  def ensure_bookable(%{meeting_type: meeting_type}) do
    if paused?(meeting_type), do: {:error, :plan_paused}, else: :ok
  end

  def ensure_bookable(_), do: :ok

  @spec paused_ids(integer()) :: MapSet.t()
  def paused_ids(user_id) when is_integer(user_id) do
    if Plans.enabled?() and Plans.effective_plan(user_id) == :free do
      types = MeetingTypeQueries.list_active_meeting_types(user_id)
      providers = video_providers(types)
      keeper = keeper_id(types, providers)

      types
      |> Enum.reject(&(&1.id == keeper and not oauth_blocked?(&1, providers)))
      |> MapSet.new(& &1.id)
    else
      MapSet.new()
    end
  end

  defp keeper_id(types, providers) do
    types
    |> Enum.reject(&oauth_blocked?(&1, providers))
    |> Enum.sort_by(&{&1.inserted_at, &1.id})
    |> List.first()
    |> then(fn
      nil -> nil
      type -> type.id
    end)
  end

  defp oauth_blocked?(type, providers) do
    type
    |> video_ids()
    |> Enum.any?(fn id -> Plans.oauth_video_provider?(Map.get(providers, id)) end)
  end

  defp video_ids(type) do
    direct = [Map.get(type, :video_integration_id)]

    from_locations =
      case Map.get(type, :locations) do
        list when is_list(list) ->
          Enum.flat_map(list, fn
            %{video_integration_ids: ids} when is_list(ids) -> ids
            _ -> []
          end)

        _ ->
          []
      end

    Enum.filter(direct ++ from_locations, &is_integer/1)
  end

  defp video_providers(types) do
    ids = types |> Enum.flat_map(&video_ids/1) |> Enum.uniq()

    if ids == [] do
      %{}
    else
      Repo.all(
        from v in "video_integrations",
          where: v.id in ^ids,
          select: {v.id, v.provider}
      )
      |> Map.new()
    end
  end
end
