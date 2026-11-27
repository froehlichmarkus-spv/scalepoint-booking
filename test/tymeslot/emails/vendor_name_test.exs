defmodule Tymeslot.Emails.VendorNameTest do
  @moduledoc """
  The old product name and the other suite vendor names stay out of every
  rendered booking mail, in German and English, HTML and plain text.
  """

  use Tymeslot.DataCase, async: true
  @moduletag :emails

  alias Tymeslot.Emails.Shared.DsMail

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
    MagicLink,
    NoPasswordToReset,
    PasswordReset,
    SignupAttemptNotice,
    SocialSignupConfirmation
  }

  import Tymeslot.EmailTestHelpers

  @forbidden ~w(Tymeslot SalesBlink FUTUREBLINK HeyLeads ScreamX IPRoyal ElevenLabs Twenty) ++
               ["TypeSafe AI"]

  @legal "https://scalepoint-ventures.com/growthos/legal/"

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
        refute_forbidden(part, "#{locale} #{email.subject}")
      end

      for href <- hrefs(email.html_body) do
        refute_forbidden(href, "#{locale} #{email.subject} href")
      end
    end
  end

  test "legal hrefs start with the growthos legal pages" do
    for locale <- ["de", "en"], email <- emails(locale) do
      where = "#{locale} #{email.subject}"
      legal = email.html_body |> hrefs() |> Enum.filter(&legal_href?/1)

      assert legal != [], "no legal href in #{where}"

      for href <- legal do
        assert String.starts_with?(href, @legal), "#{where} #{href}"
      end

      assert email.html_body =~ @legal <> "privacy"
      assert email.html_body =~ @legal <> "notice"
      refute email.html_body =~ "/de/datenschutz"
      refute email.html_body =~ "/de/impressum"
      refute email.html_body =~ "/en/privacy"
      refute email.html_body =~ "/en/legal-notice"

      # The mailer appends this footer at deliver time, in the recipient's locale.
      text =
        Gettext.with_locale(TymeslotWeb.Gettext, locale, fn ->
          DsMail.append_text_footer(email.text_body)
        end)

      text_legal = text_urls(text)
      assert text_legal != [], "no legal URL in #{where} text"

      for url <- text_legal do
        assert String.starts_with?(url, @legal), "#{where} text #{url}"
      end

      label = if locale == "de", do: "Datenschutz:", else: "Privacy:"
      assert text =~ label
      assert text =~ @legal <> "notice"
    end
  end

  test "English and German catalogues and templates omit the old product name" do
    root = Path.expand("../../../", __DIR__)

    for path <- Path.wildcard(Path.join(root, "priv/gettext/{en,de}/**/*.po")) do
      for text <- msgstr_values(File.read!(path)) do
        refute String.contains?(String.downcase(text), "tymeslot"),
               "#{Path.relative_to(path, root)} msgstr still names Tymeslot"
      end
    end

    for path <- Path.wildcard(Path.join(root, "lib/**/*.{heex,eex}")) do
      visible =
        path
        |> File.read!()
        |> String.replace(~r/\bTymeslot(Web)?\.[A-Za-z0-9_\.]*/, "")

      refute visible =~ ~r/\bTymeslot\b/,
             "#{Path.relative_to(path, root)} still shows Tymeslot"
    end
  end

  # The preview fixture's own links, with no URL override, must not carry the
  # old product name into an href either.
  test "the default booking fixture's hrefs omit the forbidden names" do
    details = build_appointment_details(%{attendee_locale: "de", organizer_locale: "de"})
    email = AppointmentConfirmation.render(:attendee, "mara@example.com", details)

    assert hrefs(email.html_body) != []

    for href <- hrefs(email.html_body) do
      refute_forbidden(href, "default fixture href")
      refute href =~ "tymeslot.example.com"
    end
  end

  defp msgstr_values(contents) do
    contents
    |> String.split("\n")
    |> Enum.reduce({nil, []}, fn line, {state, acc} ->
      cond do
        String.starts_with?(line, "msgid") ->
          {"msgid", acc}

        String.starts_with?(line, "msgstr") ->
          {"msgstr", [quoted_po(line) | acc]}

        String.starts_with?(line, "\"") and state == "msgstr" ->
          {"msgstr", [quoted_po(line) | acc]}

        String.starts_with?(line, "#") ->
          {nil, acc}

        true ->
          {state, acc}
      end
    end)
    |> elem(1)
    |> Enum.reject(&(&1 == ""))
  end

  defp quoted_po(line) do
    case Regex.run(~r/"(.*)"\s*$/, line) do
      [_line, inner] -> inner
      _no_quote -> ""
    end
  end

  defp hrefs(html) do
    ~r/href\s*=\s*"([^"]*)"/i
    |> Regex.scan(html || "")
    |> Enum.map(fn [_all, href] -> href end)
  end

  defp legal_href?(href) do
    String.starts_with?(href, "https://scalepoint-ventures.com/")
  end

  defp text_urls(text) do
    ~r/https:\/\/scalepoint-ventures\.com\/\S+/
    |> Regex.scan(text || "")
    |> Enum.map(fn [url] -> String.trim_trailing(url, ".,)") end)
  end

  defp refute_forbidden(text, where) do
    down = String.downcase(text || "")

    for name <- @forbidden do
      refute String.contains?(down, String.downcase(name)),
             "#{where} contains #{name}"
    end
  end
end
