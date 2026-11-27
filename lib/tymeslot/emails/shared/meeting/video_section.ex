defmodule Tymeslot.Emails.Shared.Meeting.VideoSection do
  @moduledoc """
  Video-meeting blocks for emails — the ticket-stub join CTA and the matching
  reminder-time pill.

  Both components take an explicit intent so they always match the surrounding
  email's stage band.
  """

  alias Tymeslot.Emails.Shared.{Sanitise, Stack, Styles}
  alias Tymeslot.Emails.Shared.Styles.Tokens

  use Gettext, backend: TymeslotWeb.Gettext

  @doc """
  A video meeting section — ticket-stub feel with a left colour rail and a
  prominent join button. The colour comes from the supplied intent.

  Options: `:title`, `:button_text`. Renders nothing unless `meeting_url` is
  a web address (`Sanitise.safe_web_url?/1`).
  """
  @spec video_meeting_section(Tokens.intent(), String.t() | nil, keyword()) :: String.t()
  def video_meeting_section(intent, meeting_url, opts \\ []) when is_atom(intent) do
    case Sanitise.sanitize_web_url(meeting_url) do
      nil -> ""
      safe_url -> join_section(intent, safe_url, opts)
    end
  end

  defp join_section(intent, safe_url, opts) do
    title = Keyword.get(opts, :title, dgettext("emails", "Video call"))
    button_text = Keyword.get(opts, :button_text, dgettext("emails", "Join meeting"))

    safe_title = Sanitise.sanitize_for_email(title)
    safe_button_text = Sanitise.sanitize_for_email(button_text)
    width = vml_width(button_text)

    tokens = Styles.intent(intent)

    Stack.spaced("""
    <mj-section
      background-color="#{tokens.tint}"
      border-left="4px solid #{tokens.accent}"
      border-radius="#{Styles.radius(:md)}"
      padding="18px 20px"
      css-class="mobile-card"
    >
      <mj-column>
        <mj-text
          font-size="11px"
          font-weight="700"
          color="#{tokens.accent_ink}"
          letter-spacing="0.12em"
          text-transform="uppercase"
          padding="0 0 4px 0"
          css-class="mobile-eyebrow"
        >
          #{dgettext("emails", "Video call")}
        </mj-text>
        <mj-text
          font-size="16px"
          font-weight="700"
          color="#{tokens.accent_ink}"
          padding="0 0 12px 0"
          line-height="1.35"
        >
          #{safe_title}
        </mj-text>
        <mj-raw>
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" bgcolor="#111E32" style="border-collapse:separate">
            <tr>
              <td align="center" bgcolor="#111E32" style="border-radius:10px;background:#111E32">
                <!--[if mso]>
                <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="#{safe_url}" style="height:48px;v-text-anchor:middle;width:#{width}px" arcsize="21%" stroke="f" fillcolor="#111E32">
                  <w:anchorlock/>
                  <center style="color:#FFFFFF;font-family:'Segoe UI',Arial,sans-serif;font-size:16px;font-weight:bold">#{safe_button_text}&nbsp;&rarr;</center>
                </v:roundrect>
                <![endif]-->
                <!--[if !mso]><!-->
                <a href="#{safe_url}" style="display:inline-block;background:#111E32;color:#FFFFFF;border:1px solid #111E32;font-family:'Segoe UI',Arial,sans-serif;font-size:16px;line-height:48px;font-weight:600;text-decoration:none;padding:0 28px;border-radius:10px;mso-hide:all">#{safe_button_text}&nbsp;&rarr;</a>
                <!--<![endif]-->
              </td>
            </tr>
          </table>
        </mj-raw>
      </mj-column>
    </mj-section>
    """)
  end

  # Outlook sizes a VML button from this width. The HTML button sizes itself.
  defp vml_width(label) do
    guessed = round(String.length(to_string(label)) * 9.2 + 76)
    guessed |> max(180) |> min(520)
  end

  @doc """
  A prominent time alert pill — usually used inside reminder emails. The caller
  supplies the intent explicitly so the pill always matches the email's stage
  band.
  """
  @spec time_alert_badge(Tokens.intent(), String.t()) :: String.t()
  def time_alert_badge(intent, time_text) when is_atom(intent) do
    label = Sanitise.sanitize_for_email(time_text)

    tokens = Styles.intent(intent)

    """
    <mj-section padding="0 0 10px 0">
      <mj-column>
        <mj-text
          align="center"
          padding="0"
          font-size="0"
        >
          <span style="display: inline-block; padding: 10px 22px; border-radius: #{Styles.radius(:pill)}; background: #{tokens.tint}; color: #{tokens.accent_ink}; font-size: 13px; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase;">#{label}</span>
        </mj-text>
      </mj-column>
    </mj-section>
    """
  end
end
