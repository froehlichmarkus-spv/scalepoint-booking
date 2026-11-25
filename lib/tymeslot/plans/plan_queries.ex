defmodule Tymeslot.Plans.Queries do
  @moduledoc false

  import Ecto.Query

  alias Tymeslot.Auth.UserSchema
  alias Tymeslot.Plans.Entitlement
  alias Tymeslot.Plans.WebhookDelivery
  alias Tymeslot.Repo

  @spec insert_entitlement(Ecto.Changeset.t(), keyword()) ::
          {:ok, Entitlement.t()} | {:error, Ecto.Changeset.t()}
  def insert_entitlement(changeset, opts) do
    Repo.insert(changeset, opts)
  end

  @spec get_entitlement(integer()) :: Entitlement.t() | nil
  def get_entitlement(user_id) do
    Repo.get_by(Entitlement, user_id: user_id)
  end

  @spec protected_user_ids() :: [integer()]
  def protected_user_ids do
    Repo.all(
      from e in Entitlement,
        where: e.status in ["active", "trialing", "past_due"],
        select: e.user_id
    )
  end

  @spec lock_entitlement(integer()) :: Entitlement.t() | nil
  def lock_entitlement(user_id) do
    Repo.one(from e in Entitlement, where: e.user_id == ^user_id, lock: "FOR UPDATE")
  end

  @spec update_entitlement!(Ecto.Changeset.t()) :: Entitlement.t()
  def update_entitlement!(changeset), do: Repo.update!(changeset)

  @spec insert_entitlement!(Ecto.Changeset.t()) :: Entitlement.t()
  def insert_entitlement!(changeset), do: Repo.insert!(changeset)

  @spec get_delivery(String.t()) :: WebhookDelivery.t() | nil
  def get_delivery(event_id), do: Repo.get_by(WebhookDelivery, event_id: event_id)

  @spec insert_delivery(Ecto.Changeset.t()) ::
          {:ok, WebhookDelivery.t()} | {:error, Ecto.Changeset.t()}
  def insert_delivery(changeset), do: Repo.insert(changeset)

  @spec user_email(integer()) :: String.t() | nil
  def user_email(user_id) do
    Repo.one(from u in UserSchema, where: u.id == ^user_id, select: u.email)
  end

  @spec get_user(integer()) :: UserSchema.t() | nil
  def get_user(user_id), do: Repo.get(UserSchema, user_id)

  @spec count_meeting_types(integer()) :: integer()
  def count_meeting_types(user_id) do
    Repo.one(from r in "meeting_types", where: r.user_id == ^user_id, select: count(r.id)) || 0
  end

  @spec count_calendars(integer()) :: integer()
  def count_calendars(user_id) do
    Repo.one(
      from r in "calendar_integrations", where: r.user_id == ^user_id, select: count(r.id)
    ) || 0
  end

  @spec lock_user(integer()) :: integer() | nil
  def lock_user(user_id) do
    Repo.one(from u in "users", where: u.id == ^user_id, lock: "FOR UPDATE", select: u.id)
  end

  @spec video_providers([integer()]) :: [{integer(), String.t()}]
  def video_providers(ids) do
    Repo.all(from v in "video_integrations", where: v.id in ^ids, select: {v.id, v.provider})
  end

  @spec due_user_ids(DateTime.t()) :: [integer()]
  def due_user_ids(now) do
    Repo.all(
      from e in Entitlement,
        where:
          e.status in ["trialing", "past_due"] or
            (not is_nil(e.current_period_end) and e.current_period_end < ^now),
        select: e.user_id
    )
  end
end
