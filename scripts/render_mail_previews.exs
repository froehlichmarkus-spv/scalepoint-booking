# Renders the v3 booking shell to HTML for local screenshots. No mail is sent.
#   MIX_ENV=test mix run scripts/render_mail_previews.exs
Code.require_file("test/support/email_test_helpers.ex")

defmodule MailPreview do
  alias Tymeslot.EmailTestHelpers
  alias Tymeslot.Emails.Shared.DsMail

  alias Tymeslot.Emails.Templates.{
    AppointmentCancellation,
    AppointmentConfirmation,
    AppointmentReminder,
    AppointmentRescheduled,
    EmailVerification,
    PasswordReset
  }

  @out Path.expand("tmp/mail-preview")
  @light Path.expand("priv/static/images/email/header-booking-light@2x.png")
  @dark Path.expand("priv/static/images/email/header-booking-dark@2x.png")

  def run do
    File.mkdir_p!(@out)

    for locale <- ["de", "en"] do
      details =
        EmailTestHelpers.build_appointment_details(%{
          attendee_locale: locale,
          organizer_locale: locale,
          attendee_name: "Mara",
          organizer_name: "Lena"
        })

      user =
        EmailTestHelpers.build_user_data(%{
          name: "Mara",
          email: "mara@example.com",
          locale: locale
        })

      mails = [
        {"confirmation-guest",
         AppointmentConfirmation.render(:attendee, "mara@example.com", details)},
        {"confirmation-host",
         AppointmentConfirmation.render(:organizer, "lena@example.com", details)},
        {"reminder", AppointmentReminder.render(:attendee, "mara@example.com", details)},
        {"reschedule", AppointmentRescheduled.render(:attendee, "mara@example.com", details)},
        {"cancellation", AppointmentCancellation.render(:attendee, "mara@example.com", details)},
        {"password-reset",
         PasswordReset.render(user, "https://book.scalepoint-ventures.com/auth/reset/tok")},
        {"verify-email",
         EmailVerification.render(user, "https://book.scalepoint-ventures.com/auth/verify/tok")},
        {"payment-refund", refund(locale)}
      ]

      for {name, email} <- mails do
        html = preview(email.html_body)
        write("#{name}-#{locale}-light.html", html)
        write("#{name}-#{locale}-dark.html", darken(html))
      end
    end
  end

  defp write(name, html) do
    path = Path.join(@out, name)
    File.write!(path, html)
    IO.puts(path)
  end

  defp preview(html) do
    html
    |> String.replace("cid:header-booking-light@booking.scalepoint", "file://#{@light}")
    |> String.replace("cid:header-booking-dark@booking.scalepoint", "file://#{@dark}")
  end

  # The dark rules already live in the stylesheet. This copy applies them
  # without waiting for prefers-color-scheme, so a headless screenshot of
  # the file shows the dark header and card.
  defp darken(html) do
    html <>
      """
      <style>
      .bg{background:#0B1220!important} .card{background:#131D2F!important;border-color:#2A3448!important}
      .tx{color:#E6EBF2!important} .t2{color:#C3CDDA!important} .mu{color:#A7B2C2!important}
      .ft,.ft td{color:#A7B2C2!important} .eb{color:#FFD98A!important} .lk{color:#5EE6D8!important}
      .btn{background:#F4F7FB!important;color:#0D1828!important}
      .pc{background:#0F1828!important;border-color:#2A3448!important}
      .hdr{background:#0E1A2C!important}
      .hdr-l{display:none!important;max-height:0!important}
      .hdr-d{display:block!important;max-height:none!important}
      </style>
      """
  end

  defp refund(locale) do
    Gettext.with_locale(TymeslotWeb.Gettext, locale, fn ->
      status = if locale == "de", do: "Erstattet", else: "Refunded"

      html =
        DsMail.document(%{
          title: status,
          headline: status,
          eyebrow: "BookDesk24 · " <> status,
          body:
            if(locale == "de",
              do: "<p>Der Betrag ist unterwegs.</p>",
              else: "<p>The amount is on its way.</p>"
            ),
          invoice: %{
            plan: "BookDesk24",
            invoice_no: "in_demo",
            status: status,
            tone: :success,
            line: if(locale == "de", do: "Erstattung", else: "Refund"),
            amount: "€49.00",
            total_label: if(locale == "de", do: "Summe", else: "Total"),
            total: "€49.00",
            note: ""
          }
        })

      %Swoosh.Email{html_body: html}
    end)
  end
end

MailPreview.run()
