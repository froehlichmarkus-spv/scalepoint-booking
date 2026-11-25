defmodule Tymeslot.Emails.SeedMailQueries do
  @moduledoc false

  import Ecto.Query

  alias Tymeslot.Auth.UserSchema
  alias Tymeslot.Repo

  @spec pending_email_jobs([String.t()]) :: [Oban.Job.t()]
  def pending_email_jobs(states) do
    Oban.Job
    |> where([j], j.worker == "Tymeslot.Workers.EmailWorker" and j.state in ^states)
    |> Repo.all()
  end

  @spec user_email(integer()) :: String.t() | nil
  def user_email(id) do
    case Repo.get(UserSchema, id) do
      %{email: email} -> email
      _user -> nil
    end
  end
end
