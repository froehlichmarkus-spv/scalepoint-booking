defmodule Tymeslot.Emails.Shared.DsMailTest do
  use Tymeslot.DataCase, async: true
  @moduletag :emails

  alias Tymeslot.Emails.Shared.{DsMail, MjmlEmail}
  alias Tymeslot.Emails.Templates.{AppointmentConfirmation, EmailVerification, PasswordReset}

  import Tymeslot.EmailTestHelpers

  test "eyebrow is BOOKING · TOPIC" do
    assert DsMail.booking_eyebrow("Confirmed") == "BookDesk24 · Confirmed"
    assert DsMail.booking_eyebrow("Bestätigt") == "BookDesk24 · Bestätigt"
  end

  test "the shell carries the header CIDs, the navy button and the legal links" do
    html =
      DsMail.document(%{
        title: "You are booked",
        eyebrow: "BOOKING · CONFIRMED",
        body: "<p>Tuesday</p>",
        cta_label: "Open booking",
        cta_url: "https://book.scalepoint-ventures.com/m/1"
      })

    assert html =~ "cid:header-booking-light@booking.scalepoint"
    assert html =~ "cid:header-booking-dark@booking.scalepoint"
    assert html =~ "BOOKING · CONFIRMED"
    assert html =~ "#111E32"
    assert html =~ DsMail.privacy_url()
    assert html =~ DsMail.notice_url()

    assert String.starts_with?(
             DsMail.privacy_url(),
             "https://scalepoint-ventures.com/growthos/legal/"
           )

    assert String.starts_with?(
             DsMail.notice_url(),
             "https://scalepoint-ventures.com/growthos/legal/"
           )

    refute html =~ "/growthos/legal/terms"
    refute html =~ "/en/privacy"
    refute html =~ "/de/datenschutz"
    assert html =~ "ScalePoint Ventures Oy"
    assert html =~ "Button not working? Paste this link into your browser:"
    assert html =~ "prefers-color-scheme:dark"
    refute html =~ "SalesBlink"
    refute html =~ "FUTUREBLINK"
  end

  test "a rendered confirmation uses the shell and attaches both headers" do
    details = build_appointment_details()
    email = AppointmentConfirmation.render(:attendee, "guest@example.com", details)

    assert email.html_body =~ "role=\"article\""
    assert email.html_body =~ "BookDesk24 ·"
    assert email.html_body =~ "cid:header-booking-light@booking.scalepoint"
    assert email.html_body =~ details.attendee_name

    cids = Enum.map(email.attachments, & &1.cid)
    assert "header-booking-light@booking.scalepoint" in cids
    assert "header-booking-dark@booking.scalepoint" in cids
  end

  test "password reset and verification do not name the upstream product" do
    user = build_user_data(%{name: "Mara", email: "mara@example.com"})

    reset = PasswordReset.render(user, "https://book.scalepoint-ventures.com/reset/tok")
    verify = EmailVerification.render(user, "https://book.scalepoint-ventures.com/verify/tok")

    for email <- [reset, verify] do
      assert email.html_body =~ "BookDesk24 ·"
      refute email.html_body =~ "Tymeslot"
      refute email.text_body =~ "Tymeslot"
    end

    assert reset.html_body =~ "#111E32"
    assert verify.html_body =~ "https://book.scalepoint-ventures.com/verify/tok"
  end

  test "plain footer names the legal pages" do
    footer = DsMail.text_footer()

    assert footer =~ DsMail.privacy_url()
    assert footer =~ DsMail.legal_line()

    assert MjmlEmail.header_cid("header-booking-dark@2x.png") ==
             "header-booking-dark@booking.scalepoint"
  end
end
