defmodule Tymeslot.Emails.Shared.MjmlEmail do
  @moduledoc """
  Base MJML template for BookDesk24 transactional emails.

  ## Anatomy

  Every transactional email now opens with a **stage band** — a full-width
  intent-coloured section whose gradient and eyebrow label tell the reader what
  kind of email this is before they read a word. Underneath the stage band an
  **organiser strip** shows the avatar, name, and title on a neutral surface.
  Content flows below into a warm off-white card, and the email closes with a
  quiet hairline footer carrying the wordmark.

  The intent is declared by the caller — `:intent` and `:eyebrow` are required
  keys on `organizer_details`. There is no inference, no default, and no
  fallback: an email that doesn't know its own intent fails to render.
  """

  require Logger

  import Swoosh.Email

  alias Swoosh.Attachment
  alias Tymeslot.Brands
  alias Tymeslot.Emails.Branding
  alias Tymeslot.Emails.Shared.{AvatarHelper, Frame, Sanitise, Stage, Styles}
  alias Tymeslot.Emails.Shared.Styles.{CSS, Tokens}
  alias Tymeslot.Infrastructure.Logging.LogFormat
  alias Tymeslot.Mailer
  alias Tymeslot.Mailer.Providers

  @locale_key :tymeslot_mail_locale

  use Gettext, backend: TymeslotWeb.Gettext

  @type organizer_details :: %{
          required(:intent) => Tokens.intent(),
          required(:eyebrow) => String.t(),
          optional(:name) => String.t() | nil,
          optional(:avatar_url) => String.t() | nil,
          optional(:title) => String.t() | nil,
          optional(:stage_title) => String.t() | nil,
          optional(:stage_subtitle) => String.t() | nil,
          optional(atom()) => term()
        }

  @doc "Compiles MJML to HTML, raising on error."
  @spec compile_mjml(String.t()) :: String.t()
  def compile_mjml(mjml_content) do
    # With no font map, MJML links Google Fonts for any of its default web
    # fonts (Roboto among them) the font stack names, so every open would
    # reach Google. An empty map links none, whatever the stack says.
    case Mjml.to_html(mjml_content, fonts: %{}) do
      {:ok, html} -> html
      {:error, errors} -> raise "MJML compilation failed: #{inspect(errors)}"
    end
  end

  @typedoc """
  Tracking category. Controls open tracking, and on Postmark the message
  stream the email is routed through. Links are never rewritten for click
  tracking, whatever the category.

    * `:transactional` — confirmations, security alerts, receipts. No opens,
      sent on the default `outbound` (transactional) stream. Safer for spam
      filters and respects user privacy.
    * `:lifecycle` — onboarding / billing nudges where engagement metrics are
      genuinely useful (welcome, trial ending, dunning). Opens on, still on
      `outbound`.
    * `:marketing` — bulk newsletters and announcements. Opens on, sent on the
      `broadcast` stream so reputation is isolated from transactional mail.

  The category itself is stashed on the email via `Tymeslot.Mailer.put_tracking/2`
  rather than resolved here: `Tymeslot.Mailer.deliver/2` reads it back at the
  delivery choke point and applies
  `Tymeslot.Mailer.Providers.tracking_options/2` for whichever provider is
  actually configured at send time. Only Postmark has message streams; on the
  other providers the stream half of the category has no equivalent and
  isolating bulk from transactional reputation is configured at the provider.
  """
  @type tracking :: Providers.tracking()

  @doc """
  Creates a base Swoosh email pre-configured for the given tracking category
  and with the product logo attached inline (CID `bookdesk24-logo.png`) so the
  system layout's logo header renders identically in every email client
  without needing an external URL.

  Defaults to `:transactional` — the safe choice for any email tied to a
  specific user action (booking confirmation, password reset, receipt).
  Override with `tracking: :lifecycle` or `tracking: :marketing` at the call
  site for templates that genuinely benefit from engagement metrics. The
  category is only stashed on the email here; `Tymeslot.Mailer.deliver/2`
  translates it into provider options at delivery time.
  """
  @spec base_email(keyword()) :: Swoosh.Email.t()
  def base_email(opts \\ []) do
    tracking = Keyword.get(opts, :tracking, :transactional)

    new()
    |> from({fetch_from_name(), fetch_from_email()})
    |> reply_to({"", fetch_reply_to()})
    |> Mailer.put_tracking(tracking)
    |> put_private(@locale_key, Gettext.get_locale(TymeslotWeb.Gettext))
    |> attach_headers()
    |> maybe_attach_custom_logo()
  end

  @doc "The locale stashed by `base_email/1`, for the plain-text footer."
  @spec mail_locale(Swoosh.Email.t()) :: String.t() | nil
  def mail_locale(%Swoosh.Email{private: private}), do: private[@locale_key]

  @doc """
  Sets `Reply-To` to the other party of a booking, so that a reply reaches
  that person instead of the instance's sending mailbox, which is often a
  no-reply address. `From` stays the instance address, keeping SPF, DKIM
  and DMARC aligned with the sending domain.

  Leaves the email untouched when there is no address (a group meeting's
  organiser copy has no single attendee), or when the address is the
  instance's own sender, where the header would add nothing.
  """
  @spec put_reply_to(Swoosh.Email.t(), String.t() | nil, String.t() | nil) :: Swoosh.Email.t()
  def put_reply_to(email, name, address) do
    if replies_reach?(address),
      do: reply_to(email, {Sanitise.sanitize_for_header(name), String.trim(address)}),
      else: email
  end

  @doc """
  Whether `put_reply_to/3` sets `Reply-To` for `address`, so that a reply
  reaches that person. A template that tells the reader to reply asks this
  first, since without the header a reply goes to the sending mailbox.
  """
  @spec replies_reach?(String.t() | nil) :: boolean()
  def replies_reach?(address) when is_binary(address) do
    address = String.trim(address)
    address != "" and not same_address?(address, fetch_from_email())
  end

  def replies_reach?(_address), do: false

  defp same_address?(address, from),
    do: String.downcase(address) == String.downcase(String.trim(from))

  # Content-ID must match the attachment filename exactly: Swoosh's SendGrid
  # adapter derives the content_id from the filename (ignoring `cid:`), and
  # Mailgun drops `cid:` entirely and keys inline images by filename.
  # Postmark and AhaSend echo the `cid:` we set. Matching filename and cid
  # is the only value that renders correctly across all four.
  @logo_cid "bookdesk24-logo.png"

  # Same shape as the suite asset notes: `header-light@booking.scalepoint`.
  # Resend sends this as `content_id`. The filename stays the PNG name.
  @header_cids %{
    "header-booking-light@2x.png" => "header-booking-light@booking.scalepoint",
    "header-booking-dark@2x.png" => "header-booking-dark@booking.scalepoint"
  }

  @doc "The Content-ID used for a tenant's own logo, when one is uploaded."
  @spec logo_cid() :: String.t()
  def logo_cid, do: @logo_cid

  @doc "Content-ID for a suite header PNG."
  @spec header_cid(String.t()) :: String.t()
  def header_cid(filename), do: Map.fetch!(@header_cids, filename)

  @doc "Header PNG filename and Content-ID pairs, light then dark."
  @spec header_assets() :: [{String.t(), String.t()}]
  def header_assets,
    do: [
      {"header-booking-light@2x.png", header_cid("header-booking-light@2x.png")},
      {"header-booking-dark@2x.png", header_cid("header-booking-dark@2x.png")}
    ]

  @doc """
  Compiles a body fragment to HTML.

  The fragment is the caller's MJML sections. The suite shell in
  `Tymeslot.Emails.Shared.DsMail` supplies the header, eyebrow, and footer,
  so this document has no stage band and no logo header of its own.
  """
  @spec compile_fragment(String.t()) :: String.t()
  def compile_fragment(mjml_content) do
    mjml = """
    <mjml>
      <mj-head>
        <mj-attributes>
          <mj-all font-family="Geist, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" />
          <mj-text font-size="15px" line-height="24px" color="#3C4656" />
          <mj-button border-radius="10px" font-weight="600" inner-padding="0 26px" />
        </mj-attributes>
      </mj-head>
      <mj-body background-color="#FFFFFF" width="520px">
        #{mjml_content}
      </mj-body>
    </mjml>
    """

    mjml
    |> compile_mjml()
    |> extract_body()
  end

  defp extract_body(html) do
    case Regex.run(~r/<body[^>]*>(.*)<\/body>/s, html) do
      [_all, inner] -> inner
      _other -> html
    end
  end

  defp attach_headers(email) do
    Enum.reduce(header_assets(), email, fn {filename, cid}, email ->
      path = Path.join([:code.priv_dir(:tymeslot), "static", "images", "email", filename])

      case File.read(path) do
        {:ok, bytes} ->
          attachment(
            email,
            Attachment.new(
              {:data, bytes},
              filename: filename,
              content_type: "image/png",
              type: :inline,
              cid: cid
            )
          )

        {:error, reason} ->
          Logger.warning("Email header image could not be read",
            path: path,
            reason: LogFormat.reason(reason)
          )

          email
      end
    end)
  end

  defp maybe_attach_custom_logo(email) do
    case Branding.custom_logo_path() do
      path when is_binary(path) ->
        case File.read(path) do
          {:ok, bytes} ->
            attachment(
              email,
              Attachment.new(
                {:data, bytes},
                filename: @logo_cid,
                content_type: "image/png",
                type: :inline,
                cid: @logo_cid
              )
            )

          _error ->
            email
        end

      _other ->
        email
    end
  end

  @doc """
  Attaches the stock or uploaded logo. The suite shell uses the header
  images instead. Kept for callers that still want the mark as its own part.
  """
  @spec attach_logo(Swoosh.Email.t()) :: Swoosh.Email.t()
  def attach_logo(email) do
    case Branding.logo_bytes() do
      {:ok, bytes} ->
        attachment(
          email,
          Attachment.new(
            {:data, bytes},
            filename: @logo_cid,
            content_type: "image/png",
            type: :inline,
            cid: @logo_cid
          )
        )

      :error ->
        Logger.warning(
          "No email logo could be read — emails will render without inline logo",
          path: Branding.stock_logo_path()
        )

        email
    end
  end

  @doc """
  The platform from-address.

  A tenant that is not the house brand keeps its own sender address.
  The house brand sends as `MAIL_FROM` / `EMAIL_FROM_ADDRESS`, so one
  verified domain carries SPF and DKIM.
  """
  @spec fetch_from_email() :: String.t()
  def fetch_from_email do
    case Brands.mail_identity() do
      %{house_brand: false, sender_email: email} when is_binary(email) and email != "" ->
        email

      _unused ->
        get_config_email_setting(:from_email)
    end
  end

  @doc """
  Display name on `From`.

  A white-label tenant's `sender_name` wins when it is set. The house
  brand uses the platform name (`MAIL_FROM`, default BookDesk24).
  """
  @spec fetch_from_name() :: String.t()
  def fetch_from_name do
    case Brands.mail_identity() do
      %{house_brand: false, sender_name: name} when is_binary(name) and name != "" ->
        name

      _unused ->
        get_config_email_setting(:from_name) || "BookDesk24"
    end
  end

  @doc """
  Reply-To used when a template does not name the other party.

  A white-label tenant does not advertise the house support address.
  """
  @spec fetch_reply_to() :: String.t()
  def fetch_reply_to do
    address =
      get_config_email_setting(:reply_to) ||
        get_config_email_setting(:support_email) ||
        "support@scalepoint-ventures.com"

    case Brands.mail_identity() do
      %{house_brand: false, sender_email: email} when is_binary(email) and email != "" ->
        if Brands.leak?(address), do: email, else: address

      _unused ->
        address
    end
  end

  defp get_config_email_setting(key) do
    case Application.get_env(:tymeslot, :email) do
      config when is_list(config) -> config[key]
      _other -> nil
    end
  end

  @doc """
  Renders the full MJML document for a transactional email.

  `organizer_details` carries the sender identity (organizer name, avatar,
  optional title) and the required `:intent` and `:eyebrow` that drive the
  stage band.
  """
  @spec base_mjml_template(String.t(), organizer_details()) :: String.t()
  def base_mjml_template(content, organizer_details) when is_map(organizer_details) do
    intent = Stage.fetch_required!(organizer_details, :intent)
    stage_eyebrow = Stage.fetch_required!(organizer_details, :eyebrow)

    raw_organizer_name = organizer_details[:name] || fetch_from_name()
    organizer_name = Sanitise.sanitize_for_email(raw_organizer_name)

    organizer_avatar =
      AvatarHelper.avatar_mjml(organizer_details[:avatar_url], raw_organizer_name)

    organizer_title =
      Sanitise.sanitize_for_email(organizer_details[:title] || Branding.brand_name())

    stage_title = organizer_details[:stage_title] || raw_organizer_name
    stage_subtitle = organizer_details[:stage_subtitle]

    Frame.wrap(%{
      title: dgettext("emails", "Message from %{name}", name: organizer_name),
      preview:
        dgettext("emails", "%{name} via %{brand}",
          name: organizer_name,
          brand: Sanitise.sanitize_for_email(Branding.brand_name())
        ),
      pre_card: logo_header(),
      stage: Stage.stage_band(intent, stage_eyebrow, stage_title, stage_subtitle),
      header: organizer_strip(organizer_avatar, organizer_name, organizer_title),
      body: content,
      footer: footer_strip()
    })
  end

  @doc """
  The shared inline-logo header rendered above the stage band. Used by both
  the transactional and system layouts so every email references the
  attached logo via `cid:#{@logo_cid}` and never falls back to a plain
  attachment.
  """
  @spec logo_header() :: String.t()
  def logo_header do
    alt = Sanitise.sanitize_for_email(Branding.brand_name())

    plate =
      if Branding.custom_logo_path() do
        """
        <mj-image
          src="cid:#{@logo_cid}"
          alt="#{alt}"
          width="150px"
          align="center"
          padding="12px 0 0 0"
          border="0"
          css-class="#{CSS.logo_plate_class()}"
        />
        """
      else
        ""
      end

    """
    <mj-section padding="0" background-color="#{Styles.canvas()}" css-class="email-canvas">
      <mj-column>
        <mj-image
          src="cid:#{header_cid("header-booking-light@2x.png")}"
          alt="#{alt}"
          width="600px"
          align="center"
          padding="0"
          border="0"
          css-class="hdr-l"
        />
        #{plate}
      </mj-column>
    </mj-section>
    """
  end

  defp organizer_strip(avatar, name, title) do
    """
    <mj-section
      padding="18px 28px 14px 28px"
      background-color="#{Styles.surface()}"
      border-bottom="1px solid #{Styles.hairline()}"
      css-class="email-surface email-hairline-bottom"
    >
      <mj-group>
        <mj-column width="16%" vertical-align="middle">
          #{avatar}
        </mj-column>
        <mj-column width="84%" vertical-align="middle">
          <mj-text
            font-size="15px"
            font-weight="700"
            padding="0 0 2px 8px"
            align="left"
            line-height="1.2"
            color="#{Styles.ink()}"
            css-class="email-ink"
          >
            #{name}
          </mj-text>
          <mj-text
            font-size="12px"
            color="#{Styles.ink_muted()}"
            padding="0 0 0 8px"
            align="left"
            line-height="1.3"
            letter-spacing="0.02em"
            css-class="email-ink-muted"
          >
            #{title}
          </mj-text>
        </mj-column>
      </mj-group>
    </mj-section>
    """
  end

  defp footer_strip do
    """
    <mj-section
      background-color="#{Styles.canvas_soft()}"
      border-radius="0 0 20px 20px"
      padding="18px 28px"
      css-class="email-canvas-soft"
    >
      <mj-column>
        <mj-text
          color="#{Styles.ink_muted()}"
          font-size="12px"
          align="center"
          line-height="1.6"
          letter-spacing="0.02em"
          css-class="email-ink-muted"
        >
          #{dgettext("emails", "Sent with care by")}
          <a href="#{Brands.footer_href()}" class="wordmark email-ink-link" style="color: #{Styles.ink()}; text-decoration: none; font-weight: 800;">#{Brands.footer_label()}</a>
        </mj-text>
      </mj-column>
    </mj-section>
    """
  end
end
