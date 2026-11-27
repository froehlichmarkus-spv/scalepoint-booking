defmodule Tymeslot.Emails.Templates.MagicLink do
  @moduledoc """
  The one-time sign-in link.

  Nothing delivers this yet: the app does not issue a magic-link token.
  The copy is here so the mailed sentence matches DS v2.9. The lifetime is
  `Tymeslot.Emails.Shared.LinkLifetime` (`:magic_link`), which points at the
  token attribute PR #7 still has to add.
  """

  use Gettext, backend: TymeslotWeb.Gettext

  alias Swoosh.Email
  alias Tymeslot.Emails.RecipientLocale
  alias Tymeslot.Emails.Shared.{Buttons, Greeting, LinkLifetime, MjmlEmail, TemplateHelper, Text}

  @intent :confirmed

  @spec render(Tymeslot.Emails.EmailService.user_map(), String.t()) :: Email.t()
  def render(user, sign_in_url) do
    RecipientLocale.with_user_locale(user, fn ->
      MjmlEmail.base_email()
      |> Email.to({user.name || user.email, user.email})
      |> Email.subject(dgettext("emails_account", "Your sign-in link"))
      |> Email.html_body(html_body(user, sign_in_url))
      |> Email.text_body(text_body(user, sign_in_url))
    end)
  end

  defp html_body(user, sign_in_url) do
    label = dgettext("emails_account", "Sign in to BookDesk24")

    mjml_content = """
    #{Text.centered_html(Greeting.html(user), padding: "8px 0 4px 0", font_size: "16px")}

    #{Text.centered_text(dgettext("emails_account", "Use the button on this device to sign in. It works once."), padding: "0 0 20px 0")}

    #{Buttons.action_button(@intent, label, sign_in_url, full_width: true, size: :large)}

    #{Text.system_footer_note(LinkLifetime.once(:magic_link))}
    """

    TemplateHelper.compile_system_template(
      mjml_content,
      dgettext("emails_account", "Sign in"),
      LinkLifetime.once(:magic_link),
      intent: @intent,
      eyebrow: dgettext("emails_account", "Sign in"),
      stage_title: dgettext("emails_account", "Your sign-in link"),
      stage_subtitle: LinkLifetime.once(:magic_link)
    )
  end

  defp text_body(user, sign_in_url) do
    """
    #{dgettext("emails_account", "Your sign-in link")}

    #{Greeting.text(user)}

    #{dgettext("emails_account", "Sign in to BookDesk24:")}
    #{sign_in_url}

    #{LinkLifetime.once(:magic_link)}
    """
  end
end
