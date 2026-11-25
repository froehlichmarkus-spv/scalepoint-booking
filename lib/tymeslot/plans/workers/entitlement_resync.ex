defmodule Tymeslot.Plans.Workers.EntitlementResync do
  @moduledoc """
  Pulls entitlements for trials, past-due accounts, and periods that have
  ended, so a missed webhook does not leave a host on the wrong plan.
  """

  use Oban.Worker, queue: :plans, max_attempts: 5

  import Ecto.Query, warn: false

  alias Tymeslot.Plans
  alias Tymeslot.Plans.BillingClient
  alias Tymeslot.Plans.Entitlement
  alias Tymeslot.Repo

  @spec enqueue(integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(user_id) when is_integer(user_id) do
    %{"user_id" => user_id} |> new() |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) when is_integer(user_id) do
    sync(user_id)
  end

  def perform(%Oban.Job{args: %{"user_id" => user_id}}) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {id, ""} -> sync(id)
      _ -> :ok
    end
  end

  def perform(%Oban.Job{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    ids =
      Repo.all(
        from e in Entitlement,
          where:
            e.status in ["trialing", "past_due"] or
              (not is_nil(e.current_period_end) and e.current_period_end < ^now),
          select: e.user_id
      )

    Enum.each(ids, &sync/1)
    :ok
  end

  defp sync(user_id) do
    case BillingClient.get_entitlement(user_id) do
      {:ok, body} ->
        payload = %{
          "data" => body["data"] || body,
          "version" => body["version"] || body["source_version"]
        }

        _ = Plans.upsert_entitlement(payload)
        :ok

      {:error, _} ->
        {:error, :retry_later}
    end
  end
end
