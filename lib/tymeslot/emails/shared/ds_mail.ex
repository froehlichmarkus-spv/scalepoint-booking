defmodule Tymeslot.Emails.Shared.DsMail do
  @moduledoc """
  The Growth OS email base (`design-system/email/base.html`) as the HTML
  half of a message. Callers keep their own plain-text twin.
  """

  alias Tymeslot.Emails.Branding
  alias Tymeslot.Emails.Shared.Sanitise

  use Gettext, backend: TymeslotWeb.Gettext

  @spec document(map()) :: String.t()
  def document(fields) do
    title = Sanitise.sanitize_for_email(fields[:title] || "")
    preview = Sanitise.sanitize_for_email(fields[:preheader] || default_preview())
    eyebrow = Sanitise.sanitize_for_email(fields[:eyebrow] || "")
    body = fields[:body] || ""
    cta = cta_html(fields[:cta_label], fields[:cta_url])
    info = info_html(fields[:info_title], fields[:facts] || fields[:info_body])

    """
    <!doctype html><html lang="de"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="color-scheme" content="light dark">
    <meta name="supported-color-schemes" content="light dark">
    <title>#{title}</title></head>
    <body class="bg" style="margin:0;padding:0;background:#F3F2EE">
    <div style="display:none;max-height:0;overflow:hidden">#{preview}</div>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F3F2EE"><tr><td align="center" style="padding:32px 12px">
    <table role="presentation" class="card" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#FFFFFF;border:1px solid #E7E5E0;border-radius:16px">
    <tr><td style="padding:0;background:#F3F2EE"><img src="#{header_src()}" width="600" height="120" alt="#{Sanitise.sanitize_for_email(Branding.brand_name())}" style="display:block;width:100%;max-width:600px;height:auto;border:0"></td></tr>
    <tr><td class="pad" style="padding:32px 40px 8px">
    <p class="eb" style="margin:0 0 10px;font:600 12px/16px Geist,Arial,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#0B6E66">#{eyebrow}</p>
    <h1 class="tx" style="margin:0 0 12px;font:600 26px/32px Geist,Arial,sans-serif;color:#111E32">#{title}</h1>
    <div class="t2" style="margin:0 0 16px;font:400 15px/24px Geist,Arial,sans-serif;color:#3C4656">#{body}</div>
    #{cta}#{info}
    </td></tr>
    <tr><td class="ft" style="padding:22px 40px 30px;font:400 12px/18px Geist,Arial,sans-serif;color:#5B6372">
    #{footer()}
    </td></tr></table></td></tr></table></body></html>
    """
  end

  @spec plain(map()) :: String.t()
  def plain(fields) do
    """
    #{fields[:title]}

    #{fields[:body]}

    #{fields[:cta_label]}: #{fields[:cta_url]}

    #{Branding.brand_name()}
    support@scalepoint-ventures.com
    """
  end

  defp default_preview do
    dgettext("emails", "Important notification from %{brand}", brand: Branding.brand_name())
  end

  defp cta_html(nil, _url), do: ""
  defp cta_html(_label, nil), do: ""

  defp cta_html(label, url) do
    label = Sanitise.sanitize_for_email(label)
    url = Sanitise.sanitize_for_email(url)

    ~s(<p style="margin:8px 0 22px"><a class="btn" href="#{url}" style="display:inline-block;background:#111E32;color:#FFFFFF;font:600 15px/46px Geist,Arial,sans-serif;text-decoration:none;padding:0 26px;border-radius:10px">#{label}</a></p>)
  end

  defp info_html(nil, _body), do: ""
  defp info_html(_title, nil), do: ""
  defp info_html(_title, []), do: ""

  defp info_html(title, rows) when is_list(rows) do
    body =
      Enum.map_join(rows, "", fn {label, value} ->
        """
        <tr>
        <td style="padding:8px 16px 8px 0;font:600 12px/18px Geist,Arial,sans-serif;letter-spacing:.04em;text-transform:uppercase;color:#835000;vertical-align:top;width:120px">#{Sanitise.sanitize_for_email(label)}</td>
        <td style="padding:8px 0;font:500 15px/22px Geist,Arial,sans-serif;color:#111E32;vertical-align:top">#{Sanitise.sanitize_for_email(value)}</td>
        </tr>
        """
      end)

    """
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:8px 0 18px;background:#F6F5F2;border:1px solid #E7E5E0;border-left:3px solid #835000;border-radius:12px">
    <tr><td colspan="2" style="padding:14px 16px 4px;font:600 12px/16px Geist,Arial,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#835000">#{Sanitise.sanitize_for_email(title)}</td></tr>
    <tr><td colspan="2" style="padding:0 16px 8px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0">#{body}</table></td></tr>
    </table>
    """
  end

  defp info_html(title, body) when is_binary(body) do
    ~s(<p style="background:#F6F5F2;border:1px solid #E7E5E0;border-left:3px solid #835000;border-radius:12px;padding:14px 16px"><b style="color:#835000">#{Sanitise.sanitize_for_email(title)}</b><br>#{body}</p>)
  end

  defp header_src do
    "/images/email/header-light@2x.png"
  end

  defp footer do
    """
    #{dgettext("emails", "Reply to this email or write to support@scalepoint-ventures.com.")}<br>
    ScalePoint Ventures Oy · Almavägen 26, 65610 Mustasaari, Finland · Business ID 3620767-9<br>
    <a href="https://scalepoint-ventures.com/growthos/legal/terms">#{dgettext("emails", "Terms")}</a>
    · <a href="https://scalepoint-ventures.com/growthos/legal/privacy">#{dgettext("emails", "Privacy")}</a>
    · <a href="https://scalepoint-ventures.com/growthos/legal/notice">#{dgettext("emails", "Legal notice")}</a>
    """
  end
end
