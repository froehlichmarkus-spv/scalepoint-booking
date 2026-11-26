defmodule Tymeslot.Emails.Shared.DsMail do
  @moduledoc """
  Growth OS mail base v3 for BookDesk24.

  The HTML and plain-text shells are the module bases
  `priv/email/booking/base.{de,en}.{html,txt}.eex`. Content slots are the
  body, an optional slot or invoice card, one navy button, and the legal
  footer. Header art is referenced by Content-ID.
  """

  alias Tymeslot.Emails.Branding
  alias Tymeslot.Emails.Shared.{MailCards, MailPolicy, Sanitise}
  alias Tymeslot.Plans

  use Gettext, backend: TymeslotWeb.Gettext

  require EEx

  @root Path.expand("../../../../priv/email/booking", __DIR__)

  EEx.function_from_file(:defp, :html_de, Path.join(@root, "base.de.html.eex"), [:assigns])
  EEx.function_from_file(:defp, :html_en, Path.join(@root, "base.en.html.eex"), [:assigns])
  EEx.function_from_file(:defp, :text_de, Path.join(@root, "base.de.txt.eex"), [:assigns])
  EEx.function_from_file(:defp, :text_en, Path.join(@root, "base.en.txt.eex"), [:assigns])

  @privacy_en "https://scalepoint-ventures.com/en/privacy"
  @privacy_de "https://scalepoint-ventures.com/de/datenschutz"

  @doc "Eyebrow: module label, then the template topic."
  @spec booking_eyebrow(String.t() | nil) :: String.t()
  def booking_eyebrow(topic) do
    topic = topic |> to_string() |> String.trim()
    if topic == "", do: "BookDesk24", else: "BookDesk24 · " <> topic
  end

  @doc "Privacy URL for the active language."
  @spec privacy_url() :: String.t()
  def privacy_url, do: if(lang() == "de", do: @privacy_de, else: @privacy_en)

  @doc "Legal-entity line in the active language."
  @spec legal_line() :: String.t()
  def legal_line do
    if lang() == "de" do
      "ScalePoint Ventures Oy · Almavägen 26, 65610 Mustasaari, Finnland · Y-Tunnus 3620767-9"
    else
      "ScalePoint Ventures Oy · Almavägen 26, 65610 Mustasaari, Finland · Business ID 3620767-9"
    end
  end

  @doc "Renders the v3 shell."
  @spec document(map()) :: String.t()
  def document(fields) do
    card = card(fields)
    cta_url = MailPolicy.allowed_url(fields[:cta_url])
    cta? = is_binary(fields[:cta_label]) and is_binary(cta_url)

    assigns = %{
      "subject" => esc(fields[:title]),
      "preheader" => esc(fields[:preheader] || default_preview()),
      "eyebrow" => esc(fields[:eyebrow] || "BookDesk24"),
      "title" => esc(fields[:headline] || fields[:title]),
      "body" => subtitle_html(fields[:subtitle]) <> (fields[:body] || ""),
      "card" => card && card.html,
      "cta" => cta?,
      "cta_label" => esc(fields[:cta_label]),
      "cta_url" => cta_url || "",
      "cta_vml_width" => vml_width(fields[:cta_label]),
      "info" => present?(fields[:info_title]) and present?(fields[:info_body]),
      "info_title" => esc(fields[:info_title]),
      "info_body" => esc(fields[:info_body]),
      "footer_reason" => esc(fields[:footer_reason] || footer_reason()),
      "powered_by" => powered_by?(fields[:organizer_user_id]),
      "unsub" => false,
      "unsub_url" => ""
    }

    lang()
    |> html(assigns)
    |> MailPolicy.scrub_vendors()
  end

  @doc "Plain-text twin of the shell, including the legal footer."
  @spec text_document(map()) :: String.t()
  def text_document(fields) do
    card = card(fields)
    cta_url = MailPolicy.allowed_url(fields[:cta_url])

    assigns = %{
      "title" => fields[:headline] || fields[:title] || "",
      "body_text" => fields[:body_text] || "",
      "card" => card && true,
      "card_text" => card && card.text,
      "cta" => is_binary(fields[:cta_label]) and is_binary(cta_url),
      "cta_label" => fields[:cta_label] || "",
      "cta_url" => cta_url || "",
      "info" => present?(fields[:info_title]),
      "info_title" => fields[:info_title] || "",
      "info_body" => fields[:info_body] || "",
      "footer_reason" => fields[:footer_reason] || footer_reason(),
      "powered_by" => powered_by?(fields[:organizer_user_id]),
      "unsub" => false,
      "unsub_url" => ""
    }

    lang()
    |> text(assigns)
    |> MailPolicy.scrub_vendors()
  end

  @doc "Plain-text legal footer appended when a template built its own text body."
  @spec text_footer() :: String.t()
  def text_footer do
    text_document(%{title: "", body_text: ""})
  end

  @doc "Appends the v3 footer unless a privacy URL is already present."
  @spec append_text_footer(String.t() | nil) :: String.t() | nil
  def append_text_footer(nil), do: nil

  def append_text_footer(text) when is_binary(text) do
    if String.contains?(text, @privacy_en) or String.contains?(text, @privacy_de) do
      MailPolicy.scrub_vendors(text)
    else
      MailPolicy.scrub_vendors(String.trim_trailing(text) <> "\n\n" <> text_footer())
    end
  end

  defp html("de", assigns), do: html_de(assigns)
  defp html(_lang, assigns), do: html_en(assigns)
  defp text("de", assigns), do: text_de(assigns)
  defp text(_lang, assigns), do: text_en(assigns)

  defp card(%{slot: spec}) when is_map(spec), do: MailCards.slot(spec)
  defp card(%{invoice: spec}) when is_map(spec), do: MailCards.invoice(spec)
  defp card(_fields), do: nil

  defp powered_by?(user_id) do
    Plans.enabled?() and Plans.effective_plan(user_id) == :free
  end

  defp lang do
    case Gettext.get_locale(TymeslotWeb.Gettext) do
      "de" -> "de"
      _other -> "en"
    end
  end

  defp default_preview do
    if lang() == "de" do
      "Eine Nachricht von #{Branding.brand_name()}"
    else
      "A message from #{Branding.brand_name()}"
    end
  end

  defp footer_reason do
    if lang() == "de" do
      "Du erhältst diese Mail zu einem Termin oder deinem Konto."
    else
      "You are receiving this email about a booking or your account."
    end
  end

  defp vml_width(nil), do: 220

  defp vml_width(label) do
    width = round(String.length(to_string(label)) * 9.2 + 76)
    width |> max(180) |> min(520)
  end

  defp subtitle_html(nil), do: ""
  defp subtitle_html(""), do: ""

  defp subtitle_html(text) do
    ~s(<p class="t2" style="margin:0 0 16px;font-family:Geist,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:16px;line-height:26px;color:#3C4656">#{esc(text)}</p>)
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
  defp esc(nil), do: ""
  defp esc(value), do: Sanitise.sanitize_for_email(to_string(value))
end
