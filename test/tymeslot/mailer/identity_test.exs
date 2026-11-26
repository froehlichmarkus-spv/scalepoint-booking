defmodule Tymeslot.Mailer.IdentityTest do
  use ExUnit.Case, async: true
  @moduletag :mailer

  alias Tymeslot.Mailer.Identity

  defp getenv(vars) do
    fn name -> Map.get(vars, name) end
  end

  test "uses the suite defaults when nothing is set" do
    assert Identity.resolve(getenv(%{})) == %{
             from_name: "BookDesk24",
             from_email: "noreply@scalepoint-ventures.com",
             reply_to: "support@scalepoint-ventures.com"
           }
  end

  test "parses a display name out of MAIL_FROM" do
    env = %{"MAIL_FROM" => "BookDesk24 <noreply@scalepoint-ventures.com>"}

    assert Identity.resolve(getenv(env)) == %{
             from_name: "BookDesk24",
             from_email: "noreply@scalepoint-ventures.com",
             reply_to: "support@scalepoint-ventures.com"
           }
  end

  test "a bare MAIL_FROM keeps EMAIL_FROM_NAME" do
    env = %{"MAIL_FROM" => "noreply@scalepoint-ventures.com", "EMAIL_FROM_NAME" => "Desk"}

    assert %{from_name: "Desk", from_email: "noreply@scalepoint-ventures.com"} =
             Identity.resolve(getenv(env))
  end

  test "EMAIL_FROM_ADDRESS remains the sender when MAIL_FROM is unset" do
    env = %{
      "EMAIL_FROM_ADDRESS" => "booking@scalepoint-ventures.com",
      "EMAIL_FROM_NAME" => "Desk"
    }

    assert Identity.resolve(getenv(env)).from_email == "booking@scalepoint-ventures.com"
    assert Identity.resolve(getenv(env)).from_name == "Desk"
  end

  test "MAIL_REPLY_TO overrides the suite reply address" do
    env = %{"MAIL_REPLY_TO" => "hello@example.com"}

    assert Identity.resolve(getenv(env)).reply_to == "hello@example.com"
  end

  test "blank values count as unset" do
    env = %{"MAIL_FROM" => "  ", "MAIL_REPLY_TO" => "", "EMAIL_FROM_ADDRESS" => "  "}

    assert Identity.resolve(getenv(env)).from_email == Identity.default_from_email()
    assert Identity.resolve(getenv(env)).reply_to == Identity.default_reply_to()
  end
end
