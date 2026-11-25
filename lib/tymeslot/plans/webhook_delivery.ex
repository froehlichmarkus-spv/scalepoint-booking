defmodule Tymeslot.Plans.WebhookDelivery do
  @moduledoc "Idempotency row for one growth-os-billing webhook delivery."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "plan_webhook_deliveries" do
    field :event_id, :string

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [:event_id])
    |> validate_required([:event_id])
    |> unique_constraint(:event_id)
  end
end
