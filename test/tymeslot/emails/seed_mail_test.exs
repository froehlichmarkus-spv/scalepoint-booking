defmodule Tymeslot.Emails.SeedMailTest do
  @moduledoc """
  Seed and demo addresses do not receive mail.

  On 24 November a "Verify your email" from Scheduler 24 was delivered to
  host@scheduler24.io, which bounced. The account was already verified and
  `SEED_NEUTRAL_TENANT` was false. The job had been queued by provisioning
  and the worker sent it anyway.
  """

  use Tymeslot.DataCase, async: false
  use Oban.Testing, repo: Tymeslot.Repo

  @moduletag :emails

  alias Tymeslot.Auth.Registration
  alias Tymeslot.Emails.SeedMailSuppress
  alias Tymeslot.Emails.SeedRecipients
  alias Tymeslot.Notifications.Email.AuthEmails
  alias Tymeslot.Repo
  alias Tymeslot.Workers.EmailWorker

  test "refuses retired domains and the disabled BookDesk24 owner" do
    assert SeedRecipients.blocked?("host@scheduler24.io")
    assert SeedRecipients.blocked?("Host@MeetDesk24.com")
    assert SeedRecipients.blocked?("host@bookdesk24.com")
    assert SeedRecipients.blocked?("booking@bookdesk24.com")

    refute SeedRecipients.blocked?("markus@scalepoint-ventures.com")
    refute SeedRecipients.blocked?("guest@example.com")
  end

  test "discards a verification job once the account is verified" do
    email = "verified-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, user, _message} =
             Registration.register_user(
               %{"email" => email, "password" => "ValidPassword123!"},
               ip: "203.0.113.50",
               via: :provisioning
             )

    {:ok, user} =
      user
      |> Ecto.Changeset.change(%{
        verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update()

    assert {:discard, "Account is already verified"} =
             AuthEmails.handle_email_verification(%{"user_id" => user.id})

    assert AuthEmails.expected_discard?("Account is already verified")
  end

  test "does nothing until the operator confirms, then cancels a pending seed job" do
    previous = System.get_env("CONFIRM_SUPPRESS_SEED_MAIL")

    try do
      System.delete_env("CONFIRM_SUPPRESS_SEED_MAIL")
      assert {:error, :not_confirmed} = SeedMailSuppress.run()

      assert {:ok, user, _message} =
               Registration.register_user(
                 %{
                   "email" => "host@scheduler24.io",
                   "password" => "ValidPassword123!"
                 },
                 ip: "203.0.113.51",
                 via: :provisioning
               )

      assert {:ok, _job} =
               Oban.insert(
                 EmailWorker.new(%{
                   "action" => "send_email_verification",
                   "user_id" => user.id,
                   "verification_url_encrypted" => "pending"
                 })
               )

      System.put_env("CONFIRM_SUPPRESS_SEED_MAIL", "yes")

      assert {:ok, cancelled} = SeedMailSuppress.run()
      assert cancelled >= 1

      refute_enqueued(
        worker: EmailWorker,
        args: %{"action" => "send_email_verification", "user_id" => user.id}
      )

      assert Repo.get(Tymeslot.Auth.UserSchema, user.id)
    after
      case previous do
        nil -> System.delete_env("CONFIRM_SUPPRESS_SEED_MAIL")
        value -> System.put_env("CONFIRM_SUPPRESS_SEED_MAIL", value)
      end
    end
  end
end
