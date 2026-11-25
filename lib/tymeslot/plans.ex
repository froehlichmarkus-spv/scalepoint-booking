defmodule Tymeslot.Plans do
  @moduledoc """
  BookDesk24 plan status, kept locally so a request never calls billing.

  A missing entitlement is Free. A new account gets a local 14-day Pro trial
  immediately. growth-os-billing later overwrites that row; an older
  `source_version` is ignored. `PLANS_ENABLED` left unset keeps the upstream
  self-host behaviour.
  """

  import Ecto.Query, warn: false

  alias Tymeslot.Auth.UserSchema
  alias Tymeslot.Plans.Entitlement
  alias Tymeslot.Plans.WebhookDelivery
  alias Tymeslot.Repo

  @free_features %{
    group_bookings_allowed: false,
    polls_allowed: false,
    recurring_bookings_allowed: false,
    meeting_payments: false,
    oauth_video_allowed: false,
    reminders_allowed: false,
    automations_allowed: false,
    booking_pages_allowed: false,
    custom_questions_allowed: true,
    analytics_allowed: true
  }

  @pro_features Map.new(@free_features, fn {key, _} -> {key, true} end)

  @doc "True when plan gating is switched on for this instance."
  @spec enabled?() :: boolean()
  def enabled?, do: Application.get_env(:tymeslot, :plans_enabled, false) == true

  @doc "`:pro` or `:free` for `user_id`, cached in the process for 60 seconds."
  @spec effective_plan(integer()) :: :free | :pro
  def effective_plan(user_id) when is_integer(user_id) do
    case cache_get(user_id) do
      nil -> user_id |> compute_plan() |> cache_put(user_id)
      plan -> plan
    end
  end

  def effective_plan(_), do: :free

  @doc "Quantity caps. `:infinity` means no cap."
  @spec limits(:free | :pro) :: %{
          meeting_types: pos_integer() | :infinity,
          calendar_integrations: pos_integer() | :infinity
        }
  def limits(:pro), do: %{meeting_types: :infinity, calendar_integrations: :infinity}
  def limits(:free), do: %{meeting_types: 1, calendar_integrations: 1}
  def limits(_), do: limits(:free)

  @doc "Feature flags for a plan. Unknown atoms stay allowed."
  @spec features(:free | :pro) :: %{optional(atom()) => boolean()}
  def features(plan) when plan in [:free, :pro] do
    base = if plan == :pro, do: @pro_features, else: @free_features
    overrides = config(:features, %{}) |> Map.get(plan, %{})
    Map.merge(base, overrides)
  end

  def features(_), do: features(:free)

  @spec feature?(:free | :pro, atom()) :: boolean()
  def feature?(plan, feature) when is_atom(feature) do
    case Map.fetch(features(plan), feature) do
      {:ok, allowed} -> allowed
      :error -> true
    end
  end

  @spec usage(integer()) :: %{
          meeting_types: non_neg_integer(),
          calendar_integrations: non_neg_integer()
        }
  def usage(user_id) when is_integer(user_id) do
    %{
      meeting_types: count("meeting_types", user_id),
      calendar_integrations: count("calendar_integrations", user_id)
    }
  end

  @doc "OAuth video providers that require Pro. Others stay available."
  @spec oauth_video_providers() :: [atom()]
  def oauth_video_providers do
    config(:oauth_video_providers, [:google_meet, :zoom, :teams])
  end

  @doc "Refuses Meet, Zoom and Teams when the host's plan does not include them."
  @spec allow_oauth_video(integer(), term()) :: :ok | {:error, atom()}
  def allow_oauth_video(user_id, provider) when is_integer(user_id) do
    if oauth_video_provider?(provider) do
      case Tymeslot.Features.check_access(user_id, :oauth_video_allowed) do
        :ok -> :ok
        {:error, :feature_access_checker_failed} = error -> error
        {:error, _} -> {:error, :pro_required}
      end
    else
      :ok
    end
  end

  def allow_oauth_video(_user_id, _provider), do: :ok

  @spec oauth_video_provider?(term()) :: boolean()
  def oauth_video_provider?(provider) do
    key = to_string(provider)
    Enum.any?(oauth_video_providers(), &(to_string(&1) == key))
  end

  @spec display_prices() :: map()
  def display_prices do
    config(:display_prices, %{
      monthly: %{
        label: "Pro monthly",
        amount: "5 €",
        interval: "month",
        lookup_key: "booking_pro_monthly"
      },
      yearly: %{
        label: "Pro yearly",
        amount: "50 €",
        interval: "year",
        lookup_key: "booking_pro_yearly",
        note: "2 months free"
      }
    })
  end

  @doc "Inserts the local Pro trial unless a row already exists."
  @spec start_local_trial(integer()) :: {:ok, Entitlement.t()} | {:error, Ecto.Changeset.t()}
  def start_local_trial(user_id) when is_integer(user_id) do
    days = config(:trial_days, 14)

    attrs = %{
      user_id: user_id,
      plan: "pro",
      status: "trialing",
      trial_ends_at: DateTime.add(now(), days, :day),
      source_version: 0,
      cancel_at_period_end: false,
      show_badge_on_pro: false
    }

    %Entitlement{}
    |> Entitlement.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: :user_id)
    |> tap(fn _ -> invalidate(user_id) end)
  end

  @doc "Writes an entitlement when `source_version` is not older than the stored one."
  @spec upsert_entitlement(map()) :: {:ok, Entitlement.t()} | {:error, term()}
  def upsert_entitlement(attrs) when is_map(attrs) do
    case normalize(attrs) do
      {:ok, normalized} ->
        result =
          Repo.transaction(fn ->
            write_entitlement(normalized)
          end)

        with {:ok, entitlement} <- result do
          invalidate(entitlement.user_id)
          {:ok, entitlement}
        end

      :error ->
        {:error, :invalid_entitlement}
    end
  end

  @doc """
  Applies one billing event. A repeated `id` is `{:ok, :duplicate}`. An older
  version does not change the row. The caller commits before answering 2xx.
  """
  @spec ingest_event(map()) :: {:ok, Entitlement.t() | :duplicate | :ignored} | {:error, term()}
  def ingest_event(%{"id" => event_id, "type" => type} = payload) when is_binary(event_id) do
    result =
      Repo.transaction(fn ->
        case reserve_delivery(event_id) do
          :duplicate ->
            :duplicate

          :ok ->
            if type == "entitlement.updated" do
              case normalize(payload) do
                {:ok, attrs} -> write_entitlement(attrs)
                :error -> Repo.rollback(:invalid_entitlement)
              end
            else
              :ignored
            end
        end
      end)

    case result do
      {:ok, %Entitlement{} = entitlement} ->
        invalidate(entitlement.user_id)
        {:ok, entitlement}

      {:ok, other} ->
        {:ok, other}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def ingest_event(_), do: {:error, :invalid_payload}

  @spec get_entitlement(integer()) :: Entitlement.t() | nil
  def get_entitlement(user_id) when is_integer(user_id) do
    Repo.get_by(Entitlement, user_id: user_id)
  end

  @spec external_user_id(integer()) :: String.t()
  def external_user_id(user_id), do: "booking:#{user_id}"

  @spec parse_external_user_id(term()) :: {:ok, integer()} | :error
  def parse_external_user_id("booking:" <> id) do
    case Integer.parse(id) do
      {n, ""} when n > 0 -> {:ok, n}
      _ -> :error
    end
  end

  def parse_external_user_id(_), do: :error

  @doc "Accounts the abandoned-signup purge must not delete."
  @spec protected_user_ids() :: [integer()]
  def protected_user_ids do
    Repo.all(
      from e in Entitlement,
        where: e.status in ["active", "trialing", "past_due"],
        select: e.user_id
    )
  end

  @doc "Drops the process cache and tells open dashboards to reload."
  @spec invalidate(integer()) :: :ok
  def invalidate(user_id) when is_integer(user_id) do
    :persistent_term.put({__MODULE__, :gen, user_id}, generation(user_id) + 1)

    Phoenix.PubSub.broadcast(
      Tymeslot.PubSub,
      "plans:#{user_id}",
      {:plan_updated, user_id}
    )

    :ok
  end

  defp write_entitlement(attrs) do
    existing =
      Repo.one(
        from e in Entitlement,
          where: e.user_id == ^attrs.user_id,
          lock: "FOR UPDATE"
      )

    cond do
      existing && existing.source_version > attrs.source_version ->
        existing

      existing ->
        existing |> Entitlement.changeset(attrs) |> Repo.update!()

      true ->
        %Entitlement{} |> Entitlement.changeset(attrs) |> Repo.insert!()
    end
  end

  defp reserve_delivery(event_id) do
    if Repo.get_by(WebhookDelivery, event_id: event_id) do
      :duplicate
    else
      case %WebhookDelivery{}
           |> WebhookDelivery.changeset(%{event_id: event_id})
           |> Repo.insert() do
        {:ok, _} ->
          :ok

        {:error, changeset} ->
          if unique_event?(changeset) or Repo.get_by(WebhookDelivery, event_id: event_id) do
            :duplicate
          else
            Repo.rollback(changeset)
          end
      end
    end
  end

  defp unique_event?(changeset) do
    Enum.any?(changeset.errors, fn
      {:event_id, _} -> true
      _ -> false
    end)
  end

  defp normalize(attrs) do
    data = Map.get(attrs, "data") || Map.get(attrs, :data) || attrs
    user_id = user_id_of(attrs, data)

    with true <- is_integer(user_id),
         plan when plan in ["free", "pro"] <- string_field(data, :plan),
         status when is_binary(status) <- string_field(data, :status) || "none" do
      {:ok,
       %{
         user_id: user_id,
         plan: plan,
         status: status,
         interval: blank_to_nil(string_field(data, :interval)),
         trial_ends_at: parse_dt(field(data, :trial_ends_at)),
         current_period_end: parse_dt(field(data, :current_period_end)),
         cancel_at_period_end: field(data, :cancel_at_period_end) == true,
         grace_until: grace_until(data),
         billing_account_ref: blank_to_nil(string_field(data, :billing_account_ref)),
         source_version: version_of(attrs, data),
         show_badge_on_pro: false
       }}
    else
      _ -> :error
    end
  end

  defp user_id_of(attrs, data) do
    cond do
      is_integer(field(data, :user_id)) ->
        field(data, :user_id)

      is_integer(field(attrs, :user_id)) ->
        field(attrs, :user_id)

      true ->
        case parse_external_user_id(
               field(data, :external_user_id) || field(attrs, :external_user_id)
             ) do
          {:ok, id} -> id
          :error -> nil
        end
    end
  end

  defp version_of(attrs, data) do
    raw =
      field(attrs, :version) || field(attrs, :source_version) || field(data, :source_version) || 0

    case raw do
      n when is_integer(n) and n >= 0 ->
        n

      n when is_binary(n) ->
        case Integer.parse(n) do
          {parsed, ""} when parsed >= 0 -> parsed
          _ -> 0
        end

      _ ->
        0
    end
  end

  defp grace_until(data) do
    case parse_dt(field(data, :grace_until)) do
      %DateTime{} = until ->
        until

      nil ->
        if string_field(data, :status) == "past_due" do
          DateTime.add(now(), config(:past_due_grace_days, 7), :day)
        end
    end
  end

  defp compute_plan(user_id) do
    cond do
      comped?(user_id) -> :pro
      true -> classify(get_entitlement(user_id), now())
    end
  end

  defp classify(nil, _), do: :free

  defp classify(%{status: "trialing", trial_ends_at: %DateTime{} = ends}, now) do
    if DateTime.compare(ends, now) == :gt, do: :pro, else: :free
  end

  defp classify(%{status: "active"}, _), do: :pro

  defp classify(%{status: "past_due", grace_until: %DateTime{} = until}, now) do
    if DateTime.compare(until, now) == :gt, do: :pro, else: :free
  end

  defp classify(_, _), do: :free

  defp comped?(user_id) do
    emails = config(:comped_user_emails, [])

    case user_email(user_id) do
      email when is_binary(email) and emails != [] ->
        down = String.downcase(email)
        Enum.any?(emails, &(String.downcase(String.trim(to_string(&1))) == down))

      _ ->
        false
    end
  end

  defp user_email(user_id) do
    Repo.one(from u in UserSchema, where: u.id == ^user_id, select: u.email)
  end

  defp count("meeting_types", user_id) do
    Repo.one(from r in "meeting_types", where: r.user_id == ^user_id, select: count(r.id)) || 0
  end

  defp count("calendar_integrations", user_id) do
    Repo.one(from r in "calendar_integrations", where: r.user_id == ^user_id, select: count(r.id)) ||
      0
  end

  defp cache_get(user_id) do
    key = {__MODULE__, :plan, user_id, generation(user_id)}

    case Process.get(key) do
      {plan, at} ->
        if System.monotonic_time(:millisecond) - at < 60_000, do: plan

      _ ->
        nil
    end
  end

  defp cache_put(plan, user_id) do
    Process.put(
      {__MODULE__, :plan, user_id, generation(user_id)},
      {plan, System.monotonic_time(:millisecond)}
    )

    plan
  end

  defp generation(user_id), do: :persistent_term.get({__MODULE__, :gen, user_id}, 0)

  defp config(key, default) do
    :tymeslot |> Application.get_env(:plans, []) |> Keyword.get(key, default)
  end

  defp field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp field(_, _), do: nil

  defp string_field(map, key) do
    case field(map, key) do
      value when is_binary(value) -> value
      value when is_atom(value) and not is_nil(value) -> to_string(value)
      _ -> nil
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp parse_dt(nil), do: nil
  defp parse_dt(%DateTime{} = dt), do: DateTime.truncate(dt, :second)

  defp parse_dt(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp parse_dt(_), do: nil

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
