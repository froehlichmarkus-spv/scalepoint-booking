defmodule Tymeslot.Emails.VendorNameTest do
  @moduledoc """
  The old product name and the other suite vendor names stay out of every
  rendered booking mail, in German and English, HTML and plain text.
  """

  use Tymeslot.DataCase, async: true
  @moduletag :emails

  alias Tymeslot.Emails.Templates.{
    AccountDeletionNotice,
    AccountInvitation,
    AppointmentCancellation,
    AppointmentConfirmation,
    AppointmentReminder,
    AppointmentRescheduled,
    EmailChangeConfirmed,
    EmailChangeNotification,
    EmailChangeVerification,
    EmailVerification,
    NoPasswordToReset,
    PasswordReset,
    SignupAttemptNotice,
    MagicLink,
    SocialSignupConfirmation
  }

  import Tymeslot.EmailTestHelpers

  @forbidden ~w(Tymeslot SalesBlink FUTUREBLINK HeyLeads ScreamX IPRoyal ElevenLabs Twenty) ++
               ["TypeSafe AI"]

  @url "https://book.scalepoint-ventures.com/auth/link"
  @at ~U[2026-10-16 09:00:00Z]

  defp user(locale),
    do: %{id: nil, email: "ada@example.com", name: "Ada", locale: locale, provider: "google"}

  defp booking(locale) do
    build_appointment_details(%{
      attendee_locale: locale,
      organizer_locale: locale,
      attendee_name: "Mara",
      organizer_name: "Lena",
      reschedule_url: "https://book.scalepoint-ventures.com/reschedule/tok",
      cancel_url: "https://book.scalepoint-ventures.com/cancel/tok",
      view_url: "https://book.scalepoint-ventures.com/meetings/tok",
      booking_url: "https://book.scalepoint-ventures.com/lena",
      meeting_url: "https://meet.example.com/room",
      attendee_video_url: "https://meet.example.com/room",
      organizer_video_url: "https://meet.example.com/room?role=host"
    })
  end

  defp emails(locale) do
    person = user(locale)
    details = booking(locale)

    [
      EmailVerification.render(person, @url),
      PasswordReset.render(person, @url),
      AccountInvitation.render(person, @url),
      NoPasswordToReset.render(person, @url),
      SignupAttemptNotice.render(person, @url, @url),
      AccountDeletionNotice.render(person, @at, @url),
      AccountDeletionNotice.render(person, @at, nil),
      SocialSignupConfirmation.render(person, "github", @url),
      MagicLink.render(person, @url),
      EmailChangeVerification.render(person, "new@example.com", @url),
      EmailChangeNotification.render(person, "new@example.com", @at),
      EmailChangeConfirmed.render(:old, person, "ada@example.com", "new@example.com", @at),
      EmailChangeConfirmed.render(:new, person, "ada@example.com", "new@example.com", @at),
      AppointmentConfirmation.render(:attendee, "mara@example.com", details),
      AppointmentConfirmation.render(:organizer, "lena@example.com", details),
      AppointmentReminder.render(:attendee, "mara@example.com", details),
      AppointmentRescheduled.render(:attendee, "mara@example.com", details),
      AppointmentCancellation.render(:attendee, "mara@example.com", details)
    ]
  end

  test "German and English HTML and text omit the forbidden names" do
    for locale <- ["de", "en"], email <- emails(locale) do
      for part <- [email.html_body, email.text_body, email.subject] do
        down = String.downcase(part || "")

        for name <- @forbidden do
          refute String.contains?(down, String.downcase(name)),
                 "#{locale} #{email.subject} contains #{name}"
        end
      end
    end
  end
end
