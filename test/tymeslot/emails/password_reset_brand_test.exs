defmodule Tymeslot.Emails.PasswordResetBrandTest do
  @moduledoc """
  A password-reset link is an address, not prose.

  The neutral brand removes the house name from mail that is not about that
  tenant. That replacement must not run inside the reset URL, or
  `book.scalepoint-ventures.com` becomes `book.BookDesk24-ventures.com`.
  Mail to a known tenant owner uses that tenant's name and sender.
  """

  use Tymeslot.DataCase, async: false
  @moduletag :emails

  alias Tymeslot.Brands
  alias Tymeslot.Emails.EmailService.AuthEmails
  alias Tymeslot.Emails.Templates.PasswordReset

  import Swoosh.TestAssertions
  import Tymeslot.EmailTestHelpers
  import Tymeslot.Test.DirectEmailSends

  setup :allow_direct_sends
  setup :set_swoosh_global

  @reset_url "https://book.scalepoint-ventures.com/auth/reset-password/tok_abc"

  defp optional_brand do
    Enum.find(Brands.documents(), &(&1.key == "neutral" and not &1.house_brand)) ||
      flunk("optional BookDesk24 tenant is missing")
  end

  test "keeps the reset URL verbatim when BookDesk24 is the active brand" do
    user = build_user_data(%{name: "Demo Host", email: "host@bookdesk24.com", username: "studio"})

    email =
      user
      |> tap(fn _unused -> Brands.bind(optional_brand()) end)
      |> PasswordReset.render(@reset_url)
      |> Brands.scrub_email()

    assert email.html_body =~ @reset_url
    assert email.text_body =~ @reset_url
    refute email.html_body =~ "BookDesk24-ventures"
    refute email.text_body =~ "BookDesk24-ventures"

    # The tenant is disabled, so the address is a demo mailbox and the send
    # is dropped instead of delivered.
    assert {:ok, :suppressed} = AuthEmails.send_password_reset(user, @reset_url)
    refute_receive {:email, _delivered}, 50
  end

  test "sends an unbound reset as ScalePoint Booking and keeps the link" do
    user = build_user_data(%{name: "Guest", email: "guest@example.com", username: "guest"})

    assert {:ok, _unused} = AuthEmails.send_password_reset(user, @reset_url)
    assert_receive {:email, delivered}, 1000
    assert delivered.from == {"Scheduler", "hello@tymeslot.app"}
    assert delivered.html_body =~ @reset_url
    assert delivered.text_body =~ @reset_url
    refute delivered.html_body =~ "bookdesk24.com"
    refute delivered.text_body =~ "bookdesk24.com"
  end

  test "brands a reset for the house owner as that tenant and keeps the link" do
    user =
      build_user_data(%{
        name: "Markus Fröhlich",
        email: "markus@scalepoint-ventures.com",
        username: "someone-else"
      })

    assert {:ok, _unused} = AuthEmails.send_password_reset(user, @reset_url)

    assert_receive {:email, email}, 1000
    assert email.from == {"Scheduler", "hello@tymeslot.app"}
    assert email.html_body =~ @reset_url
    assert email.text_body =~ @reset_url
    assert email.html_body =~ "ScalePoint Ventures"

    body =
      email.html_body
      |> String.replace("bookdesk24-logo.png", "")
      |> String.replace(~s(alt="BookDesk24"), "")
      |> String.replace("ScalePoint Growth OS BookDesk24", "ScalePoint Growth OS")
      |> String.replace("BookDesk24 ·", "·")

    refute body =~ "BookDesk24"
    refute email.text_body =~ "BookDesk24"
  end

  test "replaces the house name in prose and leaves addresses alone" do
    brand = optional_brand()

    assert Brands.scrub("Hello ScalePoint", brand) == "Hello #{brand.name}"

    assert Brands.scrub("Write to booking@scalepoint-ventures.com please", brand) ==
             "Write to booking@scalepoint-ventures.com please"

    assert Brands.scrub(
             ~s(href="https://book.scalepoint-ventures.com/auth/reset-password/tok"),
             brand
           ) =~
             ~s(href="https://book.scalepoint-ventures.com/auth/reset-password/tok")
  end
end
