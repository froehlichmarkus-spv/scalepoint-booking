defmodule Tymeslot.Plans.Workers.EntitlementResync do
  @moduledoc """
  Pulls entitlements for trials, past-due accounts, and periods that have
  ended, so a missed webhook does not leave a host on the wrong plan.
  """

  use Oban.Worker, queue: :plans, max_attempts: 5

  alias Tymeslot.Plans
  alias Tymeslot.Plans.BillingClient
  alias Tymeslot.Plans.Queries

  @spec enqueue(integer()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(user_id) when is_integer(user_id) do
    Oban.insert(new(%{"user_id" => user_id}))
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) when is_integer(user_id) do
    sync(user_id)
  end

  def perform(%Oban.Job{args: %{"user_id" => user_id}}) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {id, ""} -> sync(id)
      _unused7 -> :ok
    end
  end

  def perform(%Oban.Job{}) do
    now = DateTime.utc_now(:second)
    ids = Queries.due_user_ids(now)

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

        _unused9 = Plans.upsert_entitlement(payload)
        :ok

      {:error, :not_found} ->
        :ok

      {:error, _unused16} ->
        {:error, :retry_later}
    end
  end
end
