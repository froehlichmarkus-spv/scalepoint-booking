defmodule Tymeslot.Emails.Templates.MagicLinkTest do
  use Tymeslot.DataCase, async: true
  @moduletag :emails

  alias Tymeslot.Emails.Shared.LinkLifetime
  alias Tymeslot.Emails.Templates.{EmailVerification, MagicLink, PasswordReset}

  import Tymeslot.EmailTestHelpers

  test "verification and reset name the token lifetime, not a second number" do
    user = build_user_data(%{name: "Ada", email: "ada@example.com", locale: "en"})

    verify = EmailVerification.render(user, "https://book.scalepoint-ventures.com/auth/verify/t")
    reset = PasswordReset.render(user, "https://book.scalepoint-ventures.com/auth/reset/t")

    assert verify.html_body =~ LinkLifetime.once(:verification)
    assert verify.text_body =~ LinkLifetime.once(:verification)
    assert reset.html_body =~ LinkLifetime.once(:reset)
    assert reset.text_body =~ LinkLifetime.once(:reset)
    assert reset.html_body =~ "Save and sign in"
    refute reset.html_body =~ "Set New Password"
  end

  test "the magic-link mail says the link works once, for 15 minutes" do
    user = build_user_data(%{name: "Ada", email: "ada@example.com", locale: "en"})
    email = MagicLink.render(user, "https://book.scalepoint-ventures.com/auth/magic/t")

    assert email.html_body =~ "It works once, for 15 minutes."
    assert email.text_body =~ "It works once, for 15 minutes."
    assert email.html_body =~ ~s(href="https://book.scalepoint-ventures.com/auth/magic/t")

    refute Regex.replace(~r/href="[^"]*"/, email.html_body, "") =~
             "book.scalepoint-ventures.com/auth/magic"
  end

  test "German reset and magic-link copy uses du and the kit labels" do
    user = build_user_data(%{name: "Ada", email: "ada@example.com", locale: "de"})

    reset = PasswordReset.render(user, "https://book.scalepoint-ventures.com/auth/reset/t")
    magic = MagicLink.render(user, "https://book.scalepoint-ventures.com/auth/magic/t")

    assert reset.html_body =~ "Speichern und anmelden"
    assert reset.html_body =~ "Er funktioniert einmal und"
    assert magic.html_body =~ "Er funktioniert einmal und 15 Minuten lang."
    assert magic.html_body =~ "Bei BookDesk24 anmelden"
  end
end
