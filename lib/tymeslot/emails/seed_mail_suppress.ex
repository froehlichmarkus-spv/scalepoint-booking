defmodule Tymeslot.Emails.SeedMailSuppress do
  @moduledoc """
  Cancels pending email jobs addressed to a seed or demo mailbox.

  This does not run on boot and it does not delete users, brands, messages
  or job rows. It only moves matching Oban jobs to `cancelled`, and only
  after `CONFIRM_SUPPRESS_SEED_MAIL=yes`.

      CONFIRM_SUPPRESS_SEED_MAIL=yes mix run -e 'Tymeslot.Emails.SeedMailSuppress.run()'

  On a release, the same call is `bin/tymeslot eval` with that variable set.
  Run it only after the operator has approved it.
  """

  import Ecto.Query

  alias Tymeslot.Auth.UserSchema
  alias Tymeslot.Emails.SeedRecipients
  alias Tymeslot.Repo

  @pending ~w(available scheduled retryable executing)

  @doc """
  Cancels pending email jobs for seed and demo recipients.

  Returns `{:error, :not_confirmed}` until the confirmation variable is `yes`.
  """
  @spec run() :: {:ok, non_neg_integer()} | {:error, :not_confirmed}
  def run do
    if System.get_env("CONFIRM_SUPPRESS_SEED_MAIL") == "yes" do
      {:ok, cancel_pending()}
    else
      {:error, :not_confirmed}
    end
  end

  defp cancel_pending do
    blocked = MapSet.new(SeedRecipients.blocked_addresses())
    retired = MapSet.new(["scheduler24.io", "meetdesk24.com"])

    Oban.Job
    |> where([j], j.worker == "Tymeslot.Workers.EmailWorker" and j.state in ^@pending)
    |> Repo.all()
    |> Enum.count(fn job ->
      if seed_job?(job, blocked, retired) do
        Oban.cancel_job(job)
        true
      else
        false
      end
    end)
  end

  defp seed_job?(job, blocked, retired) do
    args = job.args || %{}

    cond do
      address_blocked?(args["email"], blocked, retired) -> true
      address_blocked?(args["to"], blocked, retired) -> true
      user_blocked?(args["user_id"], blocked, retired) -> true
      true -> false
    end
  end

  defp user_blocked?(id, blocked, retired) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> user_blocked?(int, blocked, retired)
      _ -> false
    end
  end

  defp user_blocked?(id, blocked, retired) when is_integer(id) do
    case Repo.get(UserSchema, id) do
      %{email: email} -> address_blocked?(email, blocked, retired)
      _ -> false
    end
  end

  defp user_blocked?(_id, _blocked, _retired), do: false

  defp address_blocked?(address, blocked, retired) when is_binary(address) do
    normalised = address |> String.trim() |> String.downcase()
    domain = normalised |> String.split("@") |> List.last()
    MapSet.member?(blocked, normalised) or MapSet.member?(retired, domain)
  end

  defp address_blocked?(_address, _blocked, _retired), do: false
end
