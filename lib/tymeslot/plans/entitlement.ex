defmodule Tymeslot.Plans.Entitlement do
  @moduledoc """
  Local cache of a host's BookDesk24 plan. growth-os-billing is the source of
  truth once it has pushed a version; a missing row means Free.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Tymeslot.Auth.UserSchema

  @type t :: %__MODULE__{}

  @plans ~w(free pro)
  @statuses ~w(none trialing active past_due canceled unpaid)
  @intervals ~w(month year)

  schema "plan_entitlements" do
    belongs_to :user, UserSchema
    field :plan, :string, default: "free"
    field :status, :string, default: "none"
    field :interval, :string
    field :trial_ends_at, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancel_at_period_end, :boolean, default: false
    field :grace_until, :utc_datetime
    field :billing_account_ref, :string
    field :source_version, :integer, default: 0
    field :show_badge_on_pro, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(entitlement, attrs) do
    entitlement
    |> cast(attrs, [
      :user_id,
      :plan,
      :status,
      :interval,
      :trial_ends_at,
      :current_period_end,
      :cancel_at_period_end,
      :grace_until,
      :billing_account_ref,
      :source_version,
      :show_badge_on_pro
    ])
    |> validate_required([:user_id, :plan, :status, :source_version])
    |> validate_inclusion(:plan, @plans)
    |> validate_inclusion(:status, @statuses)
    |> validate_optional(:interval, @intervals)
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_optional(changeset, field, allowed) do
    value = get_field(changeset, field)

    cond do
      is_nil(value) -> changeset
      value in allowed -> changeset
      true -> add_error(changeset, field, "is invalid")
    end
  end
end
