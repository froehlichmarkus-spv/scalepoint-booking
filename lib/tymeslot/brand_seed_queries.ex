defmodule Tymeslot.BrandSeedQueries do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Changeset
  alias Tymeslot.Auth.UserSchema
  alias Tymeslot.MeetingTypes.MeetingTypeSchema
  alias Tymeslot.Profiles.ProfileSchema
  alias Tymeslot.Repo

  @spec user_by_email(String.t()) :: UserSchema.t() | nil
  def user_by_email(email) do
    Repo.get_by(UserSchema, email: email)
  end

  @spec mark_ready(UserSchema.t(), map()) :: {:ok, UserSchema.t()} | {:error, Changeset.t()}
  def mark_ready(user, changes) do
    user
    |> Changeset.change(changes)
    |> Repo.update()
  end

  @spec update_profile(ProfileSchema.t(), map()) ::
          {:ok, ProfileSchema.t()} | {:error, Changeset.t()}
  def update_profile(profile, attrs) do
    profile
    |> ProfileSchema.basic_changeset(attrs)
    |> Repo.update()
  end

  @spec meeting_type(integer(), String.t() | nil, String.t() | nil) :: MeetingTypeSchema.t() | nil
  def meeting_type(user_id, slug, name) do
    Repo.get_by(MeetingTypeSchema, user_id: user_id, slug: slug) ||
      Repo.get_by(MeetingTypeSchema, user_id: user_id, name: name)
  end

  @spec deactivate_blank_slugs(integer()) :: {non_neg_integer(), nil}
  def deactivate_blank_slugs(user_id) do
    query =
      from(m in MeetingTypeSchema,
        where: m.user_id == ^user_id and (is_nil(m.slug) or m.slug == "")
      )

    Repo.update_all(query, set: [is_active: false])
  end

  @spec insert_document(String.t(), String.t()) :: {:ok, term()} | {:error, term()}
  def insert_document(key, body) do
    Repo.query(
      """
      insert into tenant_brands (key, document, inserted_at, updated_at)
      values ($1, $2::jsonb, now(), now())
      on conflict (key) do nothing
      """,
      [key, body]
    )
  end
end
