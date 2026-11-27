defmodule Tymeslot.Emails.Shared.MailPolicyTest do
  use Tymeslot.DataCase, async: true
  @moduletag :emails

  alias Tymeslot.Emails.Shared.{DsMail, MailCards, MailPolicy}

  alias Tymeslot.Emails.Templates.{
    AppointmentCancellation,
    AppointmentConfirmation,
    AppointmentReminder,
    AppointmentRescheduled,
    EmailVerification,
    PasswordReset
  }

  alias Tymeslot.Utils.Colour

  import Tymeslot.EmailTestHelpers

  test "shell links stay on our hosts and the vendor list is absent" do
    html =
      DsMail.document(%{
        title: "You are booked",
        eyebrow: "BookDesk24 · Confirmed",
        body: "<p>Tuesday with Lena.</p>",
        cta_label: "Open booking",
        cta_url: "https://book.scalepoint-ventures.com/m/1",
        slot:
          MailCards.slot(%{
            mon: "DEC",
            day: "2",
            title: "Intro",
            sub: "15:00",
            status: "Confirmed",
            tone: :success,
            rows: [{"Location", "Nordlicht"}]
          })
      })

    assert MailPolicy.links_allowed?(html)
    assert MailPolicy.vendors_clean?(html)
    assert html =~ "class=\"pc\""
    assert html =~ "cid:header-booking-light@booking.scalepoint"
    refute html =~ "https://pay.stripe.com"
  end

  test "a foreign call-to-action is dropped" do
    html =
      DsMail.document(%{
        title: "Reset",
        eyebrow: "BookDesk24 · Security",
        body: "<p>Reset.</p>",
        cta_label: "Open",
        cta_url: "https://evil.example/phish"
      })

    refute html =~ "evil.example"
    assert MailPolicy.links_allowed?(html)
  end

  test "booking mails render through the v3 base" do
    book = "https://book.scalepoint-ventures.com"

    details =
      build_appointment_details(%{
        reschedule_url: book <> "/reschedule/tok",
        cancel_url: book <> "/cancel/tok",
        meeting_url: nil,
        organizer_video_url: nil,
        attendee_video_url: nil,
        view_url: book <> "/meetings/tok",
        booking_url: book <> "/lena",
        dashboard_url: book <> "/dashboard/meetings"
      })

    user = build_user_data(%{name: "Mara", email: "mara@example.com", locale: "en"})

    emails = [
      AppointmentConfirmation.render(:attendee, "mara@example.com", details),
      AppointmentConfirmation.render(:organizer, "lena@example.com", details),
      AppointmentReminder.render(:attendee, "mara@example.com", details),
      AppointmentRescheduled.render(:attendee, "mara@example.com", details),
      AppointmentCancellation.render(:attendee, "mara@example.com", details),
      PasswordReset.render(user, "https://book.scalepoint-ventures.com/auth/reset/tok"),
      EmailVerification.render(user, "https://book.scalepoint-ventures.com/auth/verify/tok")
    ]

    for email <- emails do
      assert email.html_body =~ "cid:header-booking-light@booking.scalepoint"
      assert MailPolicy.links_allowed?(email.html_body)
      assert MailPolicy.vendors_clean?(email.html_body)
      assert MailPolicy.vendors_clean?(email.text_body)
    end

    assert hd(emails).html_body =~ "class=\"pc\""
  end

  test "the shell is built for Outlook: tables, bgcolor, and a VML button" do
    html =
      DsMail.document(%{
        title: "You are booked",
        eyebrow: "BookDesk24 · Confirmed",
        body: "<p>Tuesday.</p>",
        cta_label: "Join meeting",
        cta_url: "https://book.scalepoint-ventures.com/m/1"
      })

    assert html =~ ~s(role="presentation")
    assert html =~ "bgcolor="
    assert html =~ "<!--[if mso]>"
    assert html =~ "<v:roundrect"
    assert html =~ "urn:schemas-microsoft-com:vml"
    refute html =~ "display:flex"
    refute html =~ "position:fixed"
  end

  test "mail colours clear WCAG AA" do
    for {fg, bg, min} <- MailPolicy.contrast_pairs() do
      ratio = Colour.contrast_ratio(fg, bg)
      assert ratio >= min, "#{fg} on #{bg} is #{ratio}"
    end
  end
end
