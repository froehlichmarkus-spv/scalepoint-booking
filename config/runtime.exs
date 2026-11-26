import Config
require Logger

# Load `.env` before any `System.get_env/1` so it populates unset vars. Shell
# vars always win. On Cloudron `/app` is read-only and reset on every upgrade,
# so `.env` lives on the persistent `/app/data` volume.
if config_env() != :test do
  # `/app/data` is the volume both container images persist, so it is where an
  # operator's file survives an image update; the release root is where a
  # release unpacked on a host keeps its own. Both are offered, first match per
  # key, so no deployment has to be told which one it is.
  dotenv_paths =
    if System.get_env("DEPLOYMENT_TYPE") == "cloudron" do
      ["/app/data/.env"]
    else
      [
        "/app/data/.env",
        Path.join(System.get_env("RELEASE_ROOT") || Path.expand("..", __DIR__), ".env")
      ]
    end

  Tymeslot.Infrastructure.DotenvLoader.load(dotenv_paths)
end

# Helper to parse IP addresses using Erlang's built-in parser
# Supports both IPv4 and IPv6 addresses in all standard notations
parse_ip = fn ip_string ->
  case :inet.parse_address(String.to_charlist(ip_string)) do
    {:ok, ip_tuple} ->
      ip_tuple

    {:error, :einval} ->
      raise """
      Invalid LISTEN_IP: #{inspect(ip_string)}

      Must be a valid IPv4 or IPv6 address. Examples:
        IPv4: 0.0.0.0 (all interfaces), 127.0.0.1 (localhost only)
        IPv6: :: (all interfaces), ::1 (localhost only)

      Common use cases:
        - All interfaces (default): :: or 0.0.0.0
        - Localhost only (service mesh): ::1 or 127.0.0.1
        - Specific interface: fe80::1 or 192.168.1.100
      """
  end
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# =============================================================================
# HTTP PROXY CONFIGURATION
# =============================================================================
# Parse HTTP/HTTPS proxy configuration from standard environment variables.
# Supports: HTTP_PROXY, HTTPS_PROXY, NO_PROXY (case-insensitive)
# This configuration applies to all outbound HTTP requests (CalDAV, Google API, etc.)

# Credentials in a proxy URL are stored as a struct that masks the password
# wherever the application environment is inspected.
config :tymeslot, :http_proxy, Tymeslot.Infrastructure.ProxyConfig.from_env(System.get_env())

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/tymeslot start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :tymeslot, TymeslotWeb.Endpoint, server: true
end

if System.get_env("E2E") == "true" do
  config :tymeslot, TymeslotWeb.Endpoint, server: true
end

# Default legal links for booking pages, for single-organiser instances. An
# organiser's own links override them, per link. Unset or blank leaves the
# config.exs default (nil). Anything else must be an http(s) URL with a host, or
# the boot fails: a typo would otherwise ship pages with a broken legal link.
# This is only the shape check; the stricter https rule applies to values
# organisers type, and the full URL validator is not available this early.
booking_legal_link = fn var, key ->
  case System.get_env(var) |> to_string() |> String.trim() do
    "" ->
      :ok

    value ->
      valid? =
        match?(
          {:ok, %URI{scheme: scheme, host: host}}
          when scheme in ["http", "https"] and is_binary(host) and host != "",
          URI.new(value)
        )

      unless valid? do
        raise "#{var} must be an http(s) URL, got: #{inspect(value)}"
      end

      config :tymeslot, [{key, value}]
  end
end

booking_legal_link.("BOOKING_LEGAL_NOTICE_URL", :booking_legal_notice_url)
booking_legal_link.("BOOKING_PRIVACY_POLICY_URL", :booking_privacy_policy_url)

# House defaults for the public BookDesk24 site. A self-hosted install overrides
# these with the env vars above, or sets ENFORCE_LEGAL_AGREEMENTS=false.
# Tests keep the unset config from config/test.exs.
if config_env() != :test do
  growthos = "https://scalepoint-ventures.com/growthos/legal"

  unless Application.get_env(:tymeslot, :booking_legal_notice_url) do
    config :tymeslot, booking_legal_notice_url: growthos <> "/notice"
  end

  unless Application.get_env(:tymeslot, :booking_privacy_policy_url) do
    config :tymeslot, booking_privacy_policy_url: growthos <> "/privacy"
  end

  config :tymeslot,
    legal_terms_url: System.get_env("LEGAL_TERMS_URL") || growthos <> "/terms",
    legal_privacy_url: System.get_env("LEGAL_PRIVACY_URL") || growthos <> "/privacy",
    legal_dpa_url: System.get_env("LEGAL_DPA_URL") || growthos <> "/dpa"

  enforce =
    case System.get_env("ENFORCE_LEGAL_AGREEMENTS") do
      value when value in ["false", "0", "no"] -> false
      _other -> true
    end

  config :tymeslot, enforce_legal_agreements: enforce

  config :tymeslot,
         :breached_password_lookup,
         Tymeslot.Security.BreachedPasswords.Hibp
end

if config_env() == :prod do
  # Set environment for runtime detection
  config :tymeslot, :environment, :prod

  # Do not print debug messages in production
  config :logger, level: :info

  # Disable tzdata auto-updates: the release filesystem is read-only in containers.
  # Timezone data is bundled at build time; redeploy to pick up tz updates.
  config :tzdata, :autoupdate, :disabled

  # Point tzdata at a writable directory so it doesn't crash trying to write
  # poll timestamps to the read-only release filesystem. The start script
  # seeds this directory with the bundled release_ets data on first boot.
  config :tzdata, :data_dir, "/app/data/tzdata"

  # Structured JSON logging for production containers.
  #
  # `:all_except` captures every keyword metadata field passed inline or set on
  # the process, minus the noisy OTP internals listed below.
  config :logger, :default_handler,
    formatter:
      LoggerJSON.Formatters.Basic.new(metadata: {:all_except, [:conn, :socket, :mfa, :pid, :gl]})

  # Database configuration based on deployment type (define early as it's used for URL scheme)
  # "cloudron" or the legacy "main"; "docker" if DEPLOYMENT_TYPE is unset or unknown
  deployment_type = Tymeslot.Infrastructure.DeploymentType.current()

  # A blank OAuth state secret counts as unset, which leaves that provider
  # unconfigured. Documented setups ship the variables blank, so this only
  # warns, in case a blank one was meant to hold a value.
  case Tymeslot.Integrations.Shared.OAuthConfig.blank_state_secrets(System.get_env()) do
    [] ->
      :ok

    names ->
      IO.warn(
        "#{Enum.join(names, ", ")} set but blank; the provider is treated as not " <>
          "configured. Set a random value to enable it, or unset the variable.",
        []
      )
  end

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # Data-at-rest encryption keys, decoupled from SECRET_KEY_BASE so the cookie
  # signing secret can be rotated without touching stored credentials.
  # DATA_ENCRYPTION_KEY is key 1; DATA_ENCRYPTION_KEYS ("2:<b64>,1:<b64>", first
  # entry primary) adds keys for rotation. Both absent is allowed (the keyring
  # falls back to the legacy SECRET_KEY_BASE-derived key and keeps writing the
  # old format), so existing deployments upgrade with no change; a malformed
  # value stops the boot (see Tymeslot.Security.Encryption.Keyring). Once a key
  # is set, run the re-encryption sweep (see README, "Data-at-rest encryption").
  data_encryption_key = System.get_env("DATA_ENCRYPTION_KEY")
  data_encryption_keys = System.get_env("DATA_ENCRYPTION_KEYS")

  # Blank counts as unset, as it does for the keyring: Compose passes an unset
  # `${DATA_ENCRYPTION_KEY}` through as an empty string.
  if Enum.all?([data_encryption_key, data_encryption_keys], &(String.trim(&1 || "") == "")) do
    IO.warn(
      "DATA_ENCRYPTION_KEY is not set; data-at-rest credentials are still encrypted " <>
        "with a key derived from SECRET_KEY_BASE. Rotating SECRET_KEY_BASE would make " <>
        "them undecryptable. Set DATA_ENCRYPTION_KEY (e.g. `openssl rand -base64 48`) " <>
        "and run the re-encryption sweep (see README, \"Data-at-rest encryption\") to " <>
        "decouple them.",
      []
    )
  end

  config :tymeslot, Tymeslot.Security.Encryption,
    data_encryption_key: data_encryption_key,
    data_encryption_keys: data_encryption_keys,
    legacy_key_retired: System.get_env("LEGACY_KEY_RETIRED") in ["true", "1", "yes"]

  host =
    System.get_env("PHX_HOST") ||
      System.get_env("CLOUDRON_APP_DOMAIN") ||
      raise("environment variable PHX_HOST is missing")

  port = String.to_integer(System.get_env("PORT") || "4000")

  # Allowed origins for LiveView WebSocket (align with CSP 'connect-src' and site origin)
  # Both Cloudron and Docker build an allow-list from the host
  check_origin_config =
    case deployment_type do
      "cloudron" ->
        ["https://#{host}", "http://#{host}"]

      "docker" ->
        case System.get_env("WS_ALLOWED_ORIGINS") do
          nil ->
            [
              "https://#{host}",
              "http://#{host}",
              "http://localhost:4000",
              "https://localhost:4000"
            ]

          list ->
            list
            |> String.split(",")
            |> Enum.map(&String.trim/1)
        end
    end

  config :tymeslot, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # URL scheme: Cloudron always uses https, Docker defaults to https but can override
  # Production deployments should use https via reverse proxy (nginx, Caddy, Traefik, etc.)
  url_scheme =
    case deployment_type do
      "cloudron" -> "https"
      "docker" -> System.get_env("URL_SCHEME", "https")
    end

  # URL port for generation (what appears in generated URLs)
  # Production: Always use standard ports (80/443) - assumes reverse proxy on standard ports
  # Dev: Uses PORT variable directly (e.g., 4000) via dev.exs
  # This ensures production URLs never include port suffix (https://example.com not https://example.com:443)
  url_port =
    case deployment_type do
      "cloudron" -> 443
      "docker" -> if url_scheme == "https", do: 443, else: 80
    end

  # Listen IP configuration
  # Default to :: (IPv6 any address, which also accepts IPv4 on dual-stack systems)
  # Override with LISTEN_IP environment variable for specific use cases:
  #   - IPv4-only environments: LISTEN_IP=0.0.0.0
  #   - Service mesh (localhost only): LISTEN_IP=127.0.0.1 or LISTEN_IP=::1
  #   - Specific interface: LISTEN_IP=192.168.1.100 or LISTEN_IP=fe80::1
  listen_ip = System.get_env("LISTEN_IP") || "::"

  config :tymeslot, TymeslotWeb.Endpoint,
    url: [host: host, port: url_port, scheme: url_scheme],
    http: [
      ip: parse_ip.(listen_ip),
      port: port
    ],
    secret_key_base: secret_key_base,
    check_origin: check_origin_config

  # Database configuration. The mapping from environment to Repo options lives
  # in a module so it can be unit-tested; this file is never evaluated by
  # `mix test`.
  config :tymeslot,
         Tymeslot.Repo,
         Tymeslot.Infrastructure.DatabaseConfig.build(deployment_type, System.get_env())

  # Whether a forwarded address in a loopback or RFC-1918/4193 range names the
  # visitor (an intranet-only deployment) rather than a proxy hop (the default).
  # This one key drives both the LiveView socket path and, through
  # `ClientIP.remote_ip_clients/0`, the `RemoteIp` plug in the endpoint, so the
  # two cannot be configured apart. RemoteIp reads no application config, which
  # is why its options live on the plug rather than here.
  #
  # Only fixes a single proxy tier: it works when the reverse proxy directly in
  # front of the app is the only hop between it and the visitor. With a further
  # private proxy tier upstream of that one, the flag cannot tell the outer hop
  # apart from a visitor, and everyone behind it still collapses onto the outer
  # proxy's address.
  config :tymeslot,
         :trust_private_client_ips,
         TymeslotWeb.Helpers.ClientIP.trust_private_clients_from_env(
           System.get_env("TRUST_PRIVATE_CLIENT_IPS")
         )

  # Public proxy ranges (a CDN's edges, a cloud load balancer) whose addresses
  # are proxy hops rather than visitors. Like the flag above, this one key drives
  # the LiveView socket path and, through `ClientIP.remote_ip_proxies/0`, the
  # `RemoteIp` plug. An entry that does not parse stops the release here rather
  # than raising inside `RemoteIp` on every request.
  config :tymeslot,
         :trusted_proxies,
         Tymeslot.Security.TrustedProxies.from_env(System.get_env("TRUSTED_PROXIES"))

  # Configure Oban for production
  # Queue definitions in config.exs are loaded at runtime by application.ex
  # This allows SaaS to extend Core queues via :oban_additional_queues config
  config :tymeslot, Oban,
    repo: Tymeslot.Repo,
    # Allow in-flight jobs 15 seconds to finish on shutdown. Whatever is still
    # running when that expires is killed with its row left `executing`: the
    # grace period reschedules nothing, which is what the lifeline is for.
    shutdown_grace_period: :timer.seconds(15),
    # Return a job that has been `executing` for six hours to `available`, so a
    # deploy that kills a node mid-job does not strand the job and everything
    # it owed. Rescuing goes on elapsed time alone and cannot tell a dead node
    # from a slow job, so the window has to clear the longest legitimate run:
    # see `Tymeslot.Infrastructure.ObanRescue`, which holds the reasoning and
    # warns at boot when this drifts out of the safe band.
    lifeline: [rescue_after: {6, :hours}],
    pruner: [max_age: {7, :days}],
    # The crontab itself is `:oban_crontab` in config.exs, shared with dev;
    # `Tymeslot.Infrastructure.ObanCron.extend/1` fills it in at startup.
    cron: []

  # Disable the Zoom update scope where the Marketplace app behind this
  # deployment is not configured for `meeting:update:meeting`. Requesting it
  # there is silently dropped by Zoom and makes Tymeslot ask users to reconnect
  # for a scope no reconnect can produce.
  config :tymeslot,
         :zoom_update_scope_enabled,
         System.get_env("ZOOM_UPDATE_SCOPE_ENABLED") != "false"

  # Configure mailer based on EMAIL_ADAPTER setting. `Tymeslot.Mailer.Providers`
  # owns the list of supported values and the variables each one reads; an
  # unrecognised value raises rather than silently discarding every email.
  # Default to smtp for self-hosted deployments.
  # On Cloudron: auto-detect sendmail addon when EMAIL_ADAPTER is not explicitly set.
  # A set-but-blank EMAIL_ADAPTER= is treated the same as unset, so it falls
  # through to the default/auto-detection below instead of raising as an
  # unrecognised provider name.
  email_adapter_explicit =
    "EMAIL_ADAPTER" |> System.get_env() |> Tymeslot.Mailer.Providers.blank_to_nil()

  resend_api_key =
    "RESEND_API_KEY" |> System.get_env() |> Tymeslot.Mailer.Providers.blank_to_nil()

  # Nothing is delivered unless SEND_EMAILS=true. The default is off so a
  # boot, a CI run, or a recreate cannot send mail by accident.
  send_emails? = System.get_env("SEND_EMAILS") in ["true", "1", "yes"]

  # A sending key selects Resend over the default SMTP adapter. Any other
  # explicit EMAIL_ADAPTER still wins. See Tymeslot.Mailer.Providers.choose/3.
  chosen_adapter =
    if send_emails? do
      Tymeslot.Mailer.Providers.choose(:prod, email_adapter_explicit, resend_api_key)
    else
      "logger"
    end

  mailer_config =
    cond do
      chosen_adapter != nil ->
        if Tymeslot.Mailer.Providers.dev_only?(chosen_adapter) do
          raise """
          EMAIL_ADAPTER=#{chosen_adapter} is a development-only adapter.

          Swoosh's in-memory mailbox is disabled in production, so it cannot
          deliver anything. Configure a real provider, or set EMAIL_ADAPTER=test
          if you deliberately want every email discarded.
          """
        end

        Tymeslot.Mailer.Providers.build!(chosen_adapter)

      # Cloudron sendmail addon auto-detection (no explicit EMAIL_ADAPTER set)
      deployment_type == "cloudron" and System.get_env("CLOUDRON_MAIL_SMTP_SERVER") != nil ->
        Tymeslot.Mailer.CloudronConfig.build(
          server: System.get_env("CLOUDRON_MAIL_SMTP_SERVER"),
          port: System.get_env("CLOUDRON_MAIL_SMTP_PORT"),
          username: System.get_env("CLOUDRON_MAIL_SMTP_USERNAME"),
          password: System.get_env("CLOUDRON_MAIL_SMTP_PASSWORD")
        )

      # Default: standard SMTP from SMTP_* env vars
      true ->
        Tymeslot.Mailer.Providers.build!("smtp")
    end

  config :tymeslot, Tymeslot.Mailer, mailer_config
end

# Configure mailer for non-production, non-test environments. `config/test.exs`
# pins the adapter to `Swoosh.Adapters.Test` so the test suite is deterministic
# regardless of the developer's ambient EMAIL_ADAPTER; runtime.exs must never
# override that pin.
if config_env() not in [:prod, :test] do
  # Default to smtp for self-hosted deployments. A set-but-blank
  # EMAIL_ADAPTER= is treated the same as unset, so it falls through to the
  # default below instead of Providers.build/1 raising on an unrecognised
  # provider name.
  email_adapter_default = Application.get_env(:tymeslot, :email_adapter_default, "smtp")

  email_adapter =
    Tymeslot.Mailer.Providers.choose(
      config_env(),
      "EMAIL_ADAPTER"
      |> System.get_env()
      |> Tymeslot.Mailer.Providers.blank_to_nil(),
      "RESEND_API_KEY" |> System.get_env() |> Tymeslot.Mailer.Providers.blank_to_nil()
    ) || email_adapter_default

  # A provider whose credentials are absent falls back to the local mailbox at
  # /dev/mailbox rather than failing to boot: an unconfigured development
  # machine should still start. Credentials that are present but malformed
  # still raise, here as in production.
  mailer_config =
    case Tymeslot.Mailer.Providers.build(email_adapter) do
      {:ok, config} ->
        config

      {:error, reason} ->
        Logger.info(
          "EMAIL_ADAPTER=#{String.trim(email_adapter)} is not configured (#{reason}); " <>
            "delivering to the local mailbox instead"
        )

        [adapter: Swoosh.Adapters.Local]
    end

  config :tymeslot, Tymeslot.Mailer, mailer_config
end

# Platform sender. MAIL_FROM / MAIL_REPLY_TO win. EMAIL_FROM_* remains the
# fallback so a server that has not set MAIL_FROM keeps its current sender.
# The test suite still asserts the historical sender name and address.
mail_identity =
  if config_env() == :test do
    test_from = System.get_env("EMAIL_FROM_ADDRESS") || "hello@tymeslot.app"

    %{
      from_name: System.get_env("EMAIL_FROM_NAME") || "Scheduler",
      from_email: test_from,
      reply_to:
        System.get_env("MAIL_REPLY_TO") || System.get_env("EMAIL_SUPPORT_ADDRESS") || test_from
    }
  else
    Tymeslot.Mailer.Identity.resolve()
  end

from_name = mail_identity.from_name
from_email = mail_identity.from_email

support_email = System.get_env("EMAIL_SUPPORT_ADDRESS") || mail_identity.reply_to

config :tymeslot, :email,
  from_name: from_name,
  from_email: from_email,
  reply_to: mail_identity.reply_to,
  support_email: support_email,
  contact_recipient: System.get_env("EMAIL_CONTACT_RECIPIENT") || from_email,
  domain:
    System.get_env("PHX_HOST") ||
      System.get_env("CLOUDRON_APP_DOMAIN") ||
      "tymeslot.app"

# Error tracking: every exception, crash and discarded job is stored in the
# application database (ErrorTracker) with its request, LiveView or job
# context. On by default; ERROR_TRACKING_ENABLED=false switches recording off
# everywhere, crash reporting included, and stops new-error alerts with it.
# Unset leaves the compile-time default (on; off under test). A value that is
# neither on nor off fails the boot rather than guess which the operator meant.
case System.get_env("ERROR_TRACKING_ENABLED") do
  value when value in [nil, ""] ->
    :ok

  value ->
    case String.downcase(String.trim(value)) do
      on when on in ["true", "1", "yes", "on"] ->
        config :error_tracker, enabled: true

      off when off in ["false", "0", "no", "off"] ->
        config :error_tracker, enabled: false

      _other ->
        raise "ERROR_TRACKING_ENABLED must be true or false, got: #{inspect(value)}"
    end
end

# Admin alerts — disabled by default. Self-hosters can opt in by setting
# ADMIN_ALERTS_ENABLED=true and ADMIN_ALERT_EMAIL=<recipient>. Both must be
# set for emails to be delivered. See CONTRIBUTING.md for how to share alerts
# with the project as error reports.
if System.get_env("ADMIN_ALERTS_ENABLED") in ["true", "1", "yes"] do
  config :tymeslot, :admin_alerts_enabled, true
end

case System.get_env("ADMIN_ALERT_EMAIL") do
  nil -> :ok
  "" -> :ok
  email -> config :tymeslot, :admin_alert_email, email
end

# Stripe Payment Configuration (optional for core, can be configured later)
if config_env() == :prod do
  stripe_secret_key = System.get_env("STRIPE_SECRET_KEY")

  if stripe_secret_key do
    config :stripity_stripe,
      api_key: stripe_secret_key

    # Stripe webhook secret (optional)
    stripe_webhook_secret = System.get_env("STRIPE_WEBHOOK_SECRET")

    if stripe_webhook_secret do
      config :tymeslot, :stripe_webhook_secret, stripe_webhook_secret
    else
      Logger.warning(
        "STRIPE_WEBHOOK_SECRET not set: /webhooks/stripe refuses every delivery with a 503"
      )
    end

    # Stripe Connect webhook secret (separate from the platform webhook secret)
    stripe_connect_webhook_secret = System.get_env("STRIPE_CONNECT_WEBHOOK_SECRET")

    if stripe_connect_webhook_secret do
      config :tymeslot, :stripe_connect_webhook_secret, stripe_connect_webhook_secret
    end

    # Stripe Connect client ID (`ca_...`): needed to start a new OAuth
    # connection; hosts already connected keep working without it.
    stripe_connect_client_id = String.trim(System.get_env("STRIPE_CONNECT_CLIENT_ID", ""))

    if stripe_connect_client_id != "" do
      config :tymeslot, :stripe_connect_client_id, stripe_connect_client_id
    else
      Logger.warning(
        "STRIPE_CONNECT_CLIENT_ID not set: hosts cannot connect a Stripe account by OAuth"
      )
    end
  end
end

# Self-host opt-in for the meeting-payments feature. Off by default — flipping
# MEETING_PAYMENTS_ENABLED=true requires the instance owner to register their
# instance as a Stripe platform and supply STRIPE_SECRET_KEY,
# STRIPE_CONNECT_WEBHOOK_SECRET and STRIPE_CONNECT_CLIENT_ID above. The optional application fee is taken
# from each charge in basis points (0–10000); defaults to 0 so no platform cut
# is taken unless the operator explicitly sets one.
case String.downcase(System.get_env("MEETING_PAYMENTS_ENABLED", "false")) do
  truthy when truthy in ["true", "1", "yes"] ->
    config :tymeslot, :meeting_payments_enabled, true

  _ ->
    :ok
end

case System.get_env("MEETING_PAYMENTS_APPLICATION_FEE_BP") do
  nil ->
    :ok

  "" ->
    :ok

  raw ->
    case Integer.parse(raw) do
      {bp, _} when bp >= 0 and bp <= 10_000 ->
        config :tymeslot, :payment_application_fee_bp, bp

      _other ->
        raise """
        MEETING_PAYMENTS_APPLICATION_FEE_BP must be an integer between 0 and 10000
        (basis points: 100 = 1%). Got: #{inspect(raw)}
        """
    end
end

case System.get_env("VIDEO_ROOM_RETENTION_DAYS") do
  nil ->
    :ok

  "" ->
    :ok

  raw ->
    case Integer.parse(raw) do
      {days, ""} when days >= 1 ->
        config :tymeslot, :video_room_retention_days, days

      _other ->
        raise """
        VIDEO_ROOM_RETENTION_DAYS must be a whole number of days, 1 or more.
        Got: #{inspect(raw)}
        """
    end
end

# Development/test environment Stripe configuration
if config_env() in [:dev, :test] do
  config :stripity_stripe,
    api_key: System.get_env("STRIPE_SECRET_KEY", "sk_test_fake")

  config :tymeslot, :stripe_webhook_secret, System.get_env("STRIPE_WEBHOOK_SECRET")

  config :tymeslot,
         :stripe_connect_webhook_secret,
         System.get_env("STRIPE_CONNECT_WEBHOOK_SECRET")

  # Dev only: config/test.exs pins a fake value, which an exported real
  # client ID must not override.
  with :dev <- config_env(),
       client_id when client_id != "" <-
         String.trim(System.get_env("STRIPE_CONNECT_CLIENT_ID", "")) do
    config :tymeslot, :stripe_connect_client_id, client_id
  end
end

# Telegram integration feature flags (Core defaults)
# Shared bot mode: set TELEGRAM_BOT_TOKEN + TELEGRAM_BOT_USERNAME + TELEGRAM_WEBHOOK_SECRET.
# Presence of TELEGRAM_BOT_TOKEN enables shared bot mode automatically (TELEGRAM_ENABLED not needed).
# Own-bot mode: set only TELEGRAM_ENABLED=true; each user supplies their own bot token and chat ID.
telegram_bot_token = System.get_env("TELEGRAM_BOT_TOKEN")

if telegram_bot_token do
  config :tymeslot,
    telegram_notifications_allowed: true,
    telegram_shared_bot: true,
    telegram_bot_token: telegram_bot_token,
    telegram_bot_username: System.fetch_env!("TELEGRAM_BOT_USERNAME"),
    telegram_webhook_secret: System.fetch_env!("TELEGRAM_WEBHOOK_SECRET")
else
  config :tymeslot,
    telegram_notifications_allowed: System.get_env("TELEGRAM_ENABLED") == "true",
    telegram_shared_bot: false
end

# Slack integration feature flags (Core defaults)
# Webhook-URL mode: set SLACK_ENABLED=true; users paste their own Incoming Webhook URL.
# OAuth mode: set SLACK_CLIENT_ID + SLACK_CLIENT_SECRET; users connect via a Slack App.
# Presence of SLACK_CLIENT_ID also enables Slack notifications (webhook-URL mode still works).
slack_client_id = System.get_env("SLACK_CLIENT_ID")
slack_client_secret = System.get_env("SLACK_CLIENT_SECRET")
slack_enabled_flag = System.get_env("SLACK_ENABLED") == "true"

config :tymeslot,
  slack_notifications_allowed: slack_enabled_flag or not is_nil(slack_client_id),
  slack_oauth_available: not is_nil(slack_client_id) and not is_nil(slack_client_secret),
  slack_client_id: slack_client_id,
  slack_client_secret: slack_client_secret

config :tymeslot, registration_enabled: System.get_env("REGISTRATION_ENABLED", "true") == "true"
config :tymeslot, password_auth_enabled: System.get_env("PASSWORD_AUTH_ENABLED", "true") == "true"

# Social Authentication Configuration
# These environment variables control whether social login is enabled
#
# On Cloudron: auto-enable OAuth from OIDC addon unless explicitly disabled
cloudron_oidc_available? =
  System.get_env("DEPLOYMENT_TYPE") == "cloudron" and
    System.get_env("CLOUDRON_OIDC_CLIENT_ID") != nil

# Determine OAuth enabled state:
# 1. Explicit ENABLE_OAUTH_AUTH env var always wins
# 2. Cloudron OIDC addon auto-enables if present
# 3. Default: false
# Always false in test, so the shell's ENABLE_OAUTH_AUTH and OAUTH_* vars can
# neither turn the provider on nor fail the suite at boot in the checks below.
oauth_enabled =
  config_env() != :test and
    case System.get_env("ENABLE_OAUTH_AUTH") do
      "true" -> true
      "false" -> false
      nil -> cloudron_oidc_available?
      other -> raise ~s(ENABLE_OAUTH_AUTH must be "true" or "false", got: #{inspect(other)})
    end

# Not seeded in test, for the same reason as the reCAPTCHA flags below:
# config/test.exs switches every provider off, so a developer shell that
# exports ENABLE_GOOGLE_AUTH (as env.sh does) cannot give the sign-in lockout
# tests a working path they did not set up.
if config_env() != :test do
  config :tymeslot, :social_auth,
    google_enabled: System.get_env("ENABLE_GOOGLE_AUTH", "false") == "true",
    github_enabled: System.get_env("ENABLE_GITHUB_AUTH", "false") == "true",
    oauth_enabled: oauth_enabled
end

# Generic OAuth / OIDC Provider Configuration
# For SSO authentication with any OAuth2/OIDC-compliant identity provider
#
# On Cloudron: fall back to CLOUDRON_OIDC_* env vars when OAUTH_* vars are not set
oauth_client_id =
  System.get_env("OAUTH_CLIENT_ID") || System.get_env("CLOUDRON_OIDC_CLIENT_ID")

oauth_client_secret =
  System.get_env("OAUTH_CLIENT_SECRET") || System.get_env("CLOUDRON_OIDC_CLIENT_SECRET")

oauth_provider_url =
  System.get_env("OAUTH_PROVIDER_URL") || System.get_env("CLOUDRON_OIDC_ISSUER")

oauth_authorize_url =
  System.get_env("OAUTH_AUTHORIZE_URL") || System.get_env("CLOUDRON_OIDC_AUTH_ENDPOINT")

oauth_token_url =
  System.get_env("OAUTH_TOKEN_URL") || System.get_env("CLOUDRON_OIDC_TOKEN_ENDPOINT")

oauth_userinfo_url =
  System.get_env("OAUTH_USERINFO_URL") || System.get_env("CLOUDRON_OIDC_PROFILE_ENDPOINT")

# The label on the sign-in button. Only Cloudron supplies one (the name the
# Cloudron admin gave its identity provider), and it applies only when the
# credentials are Cloudron's too; otherwise the button reads "SSO".
oauth_provider_name =
  if System.get_env("OAUTH_CLIENT_ID") == nil,
    do: System.get_env("CLOUDRON_OIDC_PROVIDER_NAME")

config :tymeslot, :oauth_provider,
  name: oauth_provider_name,
  client_id: oauth_client_id,
  client_secret: oauth_client_secret,
  site: oauth_provider_url,
  authorize_url: oauth_authorize_url,
  token_url: oauth_token_url,
  userinfo_url: oauth_userinfo_url,
  scope: System.get_env("OAUTH_SCOPE", "openid email profile"),
  allow_id_fallback: System.get_env("OAUTH_ALLOW_ID_FALLBACK", "false") == "true",
  # How far the IdP's `email_verified` claim is trusted; see
  # `Tymeslot.Auth.OAuth.Providers`.
  email_verified_claim:
    (case System.get_env("OAUTH_EMAIL_VERIFIED_CLAIM", "trust_absent") do
       "trust_absent" ->
         :trust_absent

       "require" ->
         :require

       "ignore" ->
         :ignore

       other ->
         raise ~s(OAUTH_EMAIL_VERIFIED_CLAIM must be "trust_absent", "require" or "ignore", got: #{inspect(other)})
     end)

if oauth_enabled do
  # The provider's base URL is only needed to resolve an endpoint given as a
  # relative path; with absolute endpoints it may be left unset.
  relative_oauth_endpoint? =
    Enum.any?([oauth_authorize_url, oauth_token_url, oauth_userinfo_url], fn url ->
      is_binary(url) and String.trim(url) != "" and URI.parse(url).scheme == nil
    end)

  required_oauth_vars =
    Map.merge(
      %{
        "OAUTH_CLIENT_ID / CLOUDRON_OIDC_CLIENT_ID" => oauth_client_id,
        "OAUTH_CLIENT_SECRET / CLOUDRON_OIDC_CLIENT_SECRET" => oauth_client_secret,
        "OAUTH_AUTHORIZE_URL / CLOUDRON_OIDC_AUTH_ENDPOINT" => oauth_authorize_url,
        "OAUTH_TOKEN_URL / CLOUDRON_OIDC_TOKEN_ENDPOINT" => oauth_token_url,
        "OAUTH_USERINFO_URL / CLOUDRON_OIDC_PROFILE_ENDPOINT" => oauth_userinfo_url
      },
      if(relative_oauth_endpoint?,
        do: %{"OAUTH_PROVIDER_URL / CLOUDRON_OIDC_ISSUER" => oauth_provider_url},
        else: %{}
      )
    )

  missing =
    required_oauth_vars
    |> Enum.filter(fn {_, val} -> is_nil(val) or String.trim(val) == "" end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()

  if missing != [] do
    raise """
    OAuth/OIDC is enabled but required environment variables are missing or empty:

      #{Enum.join(missing, "\n  ")}

    Set all required variables or disable OAuth with ENABLE_OAUTH_AUTH=false.
    See the OIDC/SSO documentation for configuration details.
    """
  end

  # Enforce HTTPS for OAuth URLs that carry secret material or security tokens.
  # Relative paths (no scheme) are allowed: they're resolved against OAUTH_PROVIDER_URL.
  https_required_vars = %{
    "OAUTH_AUTHORIZE_URL / CLOUDRON_OIDC_AUTH_ENDPOINT" => oauth_authorize_url,
    "OAUTH_TOKEN_URL / CLOUDRON_OIDC_TOKEN_ENDPOINT" => oauth_token_url,
    "OAUTH_USERINFO_URL / CLOUDRON_OIDC_PROFILE_ENDPOINT" => oauth_userinfo_url
  }

  non_https =
    https_required_vars
    |> Enum.filter(fn {_, val} ->
      not is_nil(val) and
        not String.starts_with?(val, "https://") and
        String.starts_with?(val, "http://")
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()

  if non_https != [] do
    raise """
    OAuth/OIDC is enabled but the following URLs must use HTTPS (or be relative paths):

      #{Enum.join(non_https, "\n  ")}

    OAuth token and userinfo endpoints carry secret material (client credentials,
    access tokens) and must not be served over plaintext HTTP.
    """
  end

  if cloudron_oidc_available? and System.get_env("ENABLE_OAUTH_AUTH") == nil do
    Logger.info("Cloudron OIDC addon auto-enabled",
      issuer: oauth_provider_url,
      client_id: oauth_client_id
    )
  end
end

# reCAPTCHA configuration (runtime)
# Signup and booking protection are configurable and will automatically
# disable if keys are missing. The settings below come from the matching env
# vars. One left unset can be changed at runtime from the admin settings UI
# (which writes through Tymeslot.AppSettings); one that is set fixes the
# setting, and the admin UI shows it greyed out.

recaptcha_signup_min_score =
  case Float.parse(System.get_env("RECAPTCHA_SIGNUP_MIN_SCORE", "0.3")) do
    {score, _} -> score
    :error -> 0.3
  end

recaptcha_booking_min_score =
  case Float.parse(System.get_env("RECAPTCHA_BOOKING_MIN_SCORE", "0.3")) do
    {score, _} -> score
    :error -> 0.3
  end

recaptcha_signup_action = System.get_env("RECAPTCHA_SIGNUP_ACTION", "signup_form")
recaptcha_booking_action = System.get_env("RECAPTCHA_BOOKING_ACTION", "booking_form")

recaptcha_expected_hostnames =
  System.get_env("RECAPTCHA_EXPECTED_HOSTNAMES", "")
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))

config :tymeslot, :recaptcha,
  signup_min_score: recaptcha_signup_min_score,
  signup_action: recaptcha_signup_action,
  booking_min_score: recaptcha_booking_min_score,
  booking_action: recaptcha_booking_action,
  expected_hostnames: recaptcha_expected_hostnames

# The enabled flags are seeded from env in non-test environments only — test
# config sets them explicitly in config/test.exs so the
# developer shell can't accidentally enable reCAPTCHA for tests by exporting
# RECAPTCHA_SIGNUP_ENABLED.
if config_env() != :test do
  config :tymeslot, :recaptcha,
    signup_enabled: System.get_env("RECAPTCHA_SIGNUP_ENABLED", "false") == "true",
    booking_enabled: System.get_env("RECAPTCHA_BOOKING_ENABLED", "false") == "true"
end

# Admin-editable settings whose environment variable the operator has set.
# A pinned setting outranks a value saved on the admin settings page, which
# shows it greyed out and names the variable. Only a value the variable's
# parse above explicitly recognises pins it; an unrecognised one (say
# REGISTRATION_ENABLED=1) is logged at boot and leaves the admin page in
# charge. Not seeded in test, for the same reason as the reCAPTCHA flags
# above: tests pin settings explicitly.
if config_env() != :test do
  {env_pinned_settings, env_unrecognised_settings} =
    Tymeslot.AppSettings.EnvPins.from_env(System.get_env())

  config :tymeslot,
    env_pinned_settings: env_pinned_settings,
    env_unrecognised_settings: env_unrecognised_settings
end

# Webhook base URL for inbound push notifications from calendar providers.
# Required to enable Google Calendar push channels and Outlook Graph subscriptions.
# When unset or blank, push channel registration is silently skipped (integrations
# still work via polling fallback).
#
# A blank value is treated as unset: an empty string is truthy in Elixir, so deployment
# templates that pass `${WEBHOOK_BASE_URL:-}` would otherwise configure a host-less URL
# and generate broken notification endpoints like "/webhooks/outlook-calendar".
webhook_base_url = System.get_env("WEBHOOK_BASE_URL")

if webhook_base_url && String.trim(webhook_base_url) != "" do
  config :tymeslot, :webhook_base_url, String.trim(webhook_base_url)
end

# Self-host escape hatch for SSRF protection on calendar integrations. In :prod,
# outbound requests to CalDAV servers whose hostname resolves to a
# private/loopback/link-local address are blocked (Tymeslot.Security.SsrfGuard).
# Operators who intentionally run those integrations on a private network — the
# common self-hosting case — opt out by setting ALLOW_PRIVATE_IPS_FOR_CALENDAR=true.
#
# This also satisfies video unless ALLOW_PRIVATE_IPS_FOR_VIDEO below is set;
# that is the dedicated video switch.
#
# This does NOT relax webhook SSRF protection (Tymeslot.Webhooks.SsrfValidator);
# webhooks have their own switch (ALLOW_PRIVATE_IPS_FOR_WEBHOOKS below).
#
# With this (or ALLOW_PRIVATE_IPS_FOR_VIDEO) set, a server on an internal name
# (http://nextcloud, http://talk.lan) may be saved with plain http. Each such
# request is still resolved first and refused unless the name resolves only to
# private addresses, since it carries credentials in clear text.
#
# Seeded from env in non-test environments only, so an exported shell var can't
# flip the default for the test suite (tests set the flag explicitly).
if config_env() != :test and
     System.get_env("ALLOW_PRIVATE_IPS_FOR_CALENDAR") in ["true", "1", "yes"] do
  config :tymeslot, :allow_private_ips_for_calendar, true
end

# Video-scoped sibling of the above, covering both self-hosted MiroTalk and the
# custom video link's reachability test. Set ALLOW_PRIVATE_IPS_FOR_VIDEO=true to
# run a meeting server on an internal network without relaxing calendar SSRF.
#
# Unlike its siblings this key is left absent when the variable is unset or
# blank, rather than written as false. Absent is what lets the calendar switch
# above go on satisfying video, while an operator who writes
# ALLOW_PRIVATE_IPS_FOR_VIDEO=false has answered for video and is not overruled
# by it; `Tymeslot.Security.SsrfGuard.allow_private_for_video?/0` reads the
# three states. `start-docker.sh` passes the variable through unset for the same
# reason.
allow_private_ips_for_video = String.trim(System.get_env("ALLOW_PRIVATE_IPS_FOR_VIDEO", ""))

if config_env() != :test and allow_private_ips_for_video != "" do
  config :tymeslot,
         :allow_private_ips_for_video,
         allow_private_ips_for_video in ["true", "1", "yes"]
end

# Webhook-scoped sibling of the above. In :prod, outbound webhook deliveries to
# a URL whose hostname resolves to a private/loopback/link-local address are
# blocked (Tymeslot.Webhooks.SsrfValidator). Operators who intentionally point
# webhooks at internal services opt out with ALLOW_PRIVATE_IPS_FOR_WEBHOOKS=true.
#
# Deliberately separate from ALLOW_PRIVATE_IPS_FOR_CALENDAR: relaxing calendar
# and video SSRF should not silently open outbound webhooks to internal hosts.
if config_env() != :test and
     System.get_env("ALLOW_PRIVATE_IPS_FOR_WEBHOOKS") in ["true", "1", "yes"] do
  config :tymeslot, :allow_private_ips_for_webhooks, true
end

# Base URL for docs hub links across the dashboard and the feature-announcement
# modal (Tymeslot.Docs, the single reader of this key).
# Defaults to the hosted docs site; a self-hoster running their own docs points
# this at it instead. A blank value is treated as unset for the same reason as
# WEBHOOK_BASE_URL above. A trailing slash is trimmed by the reader, not here.
docs_article_base_url = System.get_env("DOCS_ARTICLE_BASE_URL")

if docs_article_base_url && String.trim(docs_article_base_url) != "" do
  config :tymeslot, :docs_article_base_url, String.trim(docs_article_base_url)
end

# Local demo only. Production leaves this unset so a page stays closed until
# a real calendar is connected.
if dir = System.get_env("UPLOAD_DIRECTORY") do
  config :tymeslot, :upload_directory, dir
end

if System.get_env("SPV_DEMO_CALENDAR") == "true" do
  providers = Application.get_env(:tymeslot, :calendar_providers, %{})
  config :tymeslot, :calendar_providers, Map.put(providers, :demo, enabled: true)
end

# BookDesk24 plan gating. Off by default so a self-hosted install and the
# upstream test suite keep the open feature checker. Subscription events stay
# on growth-os-billing; this process only stores the pushed entitlement.
plans_enabled? = fn ->
  System.get_env("PLANS_ENABLED") in ["true", "1", "yes"]
end

comped_emails =
  "PLANS_COMPED_EMAILS"
  |> System.get_env("")
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))

free_calendar_providers =
  case System.get_env("PLANS_FREE_CALENDAR_PROVIDERS") do
    nil -> nil
    "" -> nil
    list -> list |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
  end

trim_env = fn
  value when is_binary(value) ->
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end

  _missing ->
    nil
end

billing_url = trim_env.(System.get_env("GROWTH_OS_BILLING_URL"))
billing_api_key = trim_env.(System.get_env("GROWTH_OS_BILLING_API_KEY"))
billing_webhook_secret = trim_env.(System.get_env("GROWTH_OS_BILLING_WEBHOOK_SECRET"))

config :tymeslot, :plans,
  past_due_grace_days: 7,
  trial_days: 14,
  comped_user_emails: comped_emails,
  free_calendar_providers: free_calendar_providers,
  oauth_video_providers: [:google_meet, :zoom, :teams],
  billing_url: billing_url,
  billing_api_key: billing_api_key,
  webhook_secret: billing_webhook_secret,
  display_prices: %{
    monthly: %{
      label: "Pro monthly",
      amount: "5 €",
      interval: "month",
      lookup_key: "booking_pro_monthly"
    },
    yearly: %{
      label: "Pro yearly",
      amount: "50 €",
      interval: "year",
      lookup_key: "booking_pro_yearly",
      note: "2 months free"
    }
  }

# Keep this address aligned with Tymeslot.Licensing.SourceOffer.default_url/0.
source_offer_url =
  case System.get_env("SOURCE_OFFER_URL") do
    nil ->
      if config_env() == :test,
        do: nil,
        else: "https://github.com/froehlichmarkus-spv/scalepoint-booking"

    "" ->
      nil

    url ->
      String.trim(url)
  end

if is_binary(source_offer_url) and source_offer_url != "" do
  config :tymeslot, :source_offer_url, source_offer_url
end

if ics_branding_url = System.get_env("ICS_BRANDING_URL") do
  trimmed = String.trim(ics_branding_url)

  if trimmed != "" do
    config :tymeslot, :ics_branding_url, trimmed
  end
end

if plans_enabled?.() do
  config :tymeslot, :plans_enabled, true
  config :tymeslot, :feature_access_checker, Tymeslot.Plans.AccessChecker
  config :tymeslot, :subscription_manager, Tymeslot.Plans.SubscriptionManager
  config :tymeslot, :show_branding, true
  config :tymeslot, :user_registered_hook, Tymeslot.Plans.UserRegisteredHook
  config :tymeslot, :account_deletion_hook, Tymeslot.Plans.AccountDeletionHook

  billing_client =
    if is_binary(billing_url) and is_binary(billing_api_key) do
      Tymeslot.Plans.BillingClient.HTTP
    else
      Tymeslot.Plans.BillingClient.Stub
    end

  config :tymeslot, :billing_client, billing_client

  config :tymeslot,
         :dashboard_additional_hooks,
         Application.get_env(:tymeslot, :dashboard_additional_hooks, []) ++
           [{TymeslotWeb.Hooks.PlanAssignsHook, :assign_plan}]

  config :tymeslot,
         :dashboard_notice_components,
         Application.get_env(:tymeslot, :dashboard_notice_components, []) ++
           [TymeslotWeb.Dashboard.PlanNoticeComponent]

  config :tymeslot,
         :dashboard_sidebar_extensions,
         Application.get_env(:tymeslot, :dashboard_sidebar_extensions, []) ++
           [
             %{
               id: :plan,
               label: "Plan & billing",
               icon: "hero-credit-card",
               path: "/dashboard/plan",
               action: :plan
             }
           ]

  config :tymeslot,
         :dashboard_action_components,
         Map.put(
           Application.get_env(:tymeslot, :dashboard_action_components, %{}),
           :plan,
           TymeslotWeb.Dashboard.PlanComponent
         )

  config :tymeslot,
         :dashboard_feature_gates,
         Map.merge(Application.get_env(:tymeslot, :dashboard_feature_gates, %{}), %{
           polls: :polls_allowed,
           payments: :meeting_payments
         })

  config :tymeslot,
         :theme_extensions,
         Application.get_env(:tymeslot, :theme_extensions, []) ++
           [{TymeslotWeb.Branding.PoweredBy, :badge}]

  config :tymeslot,
         :oban_additional_crontab,
         Application.get_env(:tymeslot, :oban_additional_crontab, []) ++
           [{"0 */6 * * *", Tymeslot.Plans.Workers.EntitlementResync}]
end
