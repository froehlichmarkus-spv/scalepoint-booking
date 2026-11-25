defmodule Tymeslot.BrandSeed do
  @moduledoc """
  Seeds one account, page, and calendar per enabled brand document.

  Idempotent. Passwords come from `SPV_OWNER_PASSWORD` and
  `NEUTRAL_OWNER_PASSWORD`, or are generated and written under `/tmp`.
  A local demo calendar is attached only when `SPV_DEMO_CALENDAR=true`.
  """

  require Logger

  alias Swoosh.Email
  alias Tymeslot.Auth
  alias Tymeslot.Availability.AvailabilityActions
  alias Tymeslot.Availability.AvailabilityScheduleQueries
  alias Tymeslot.Availability.WeeklySchedule
  alias Tymeslot.Brands
  alias Tymeslot.BrandSeedQueries
  alias Tymeslot.Emails.Delivery
  alias Tymeslot.Emails.Shared.Layouts
  alias Tymeslot.Emails.Shared.MjmlEmail
  alias Tymeslot.Infrastructure.Logging.LogFormat
  alias Tymeslot.Integrations.Calendar.IcsGenerator
  alias Tymeslot.Integrations.Calendar.Management
  alias Tymeslot.MeetingTypes
  alias Tymeslot.Profiles
  alias Tymeslot.Profiles.Avatars
  alias Tymeslot.Profiles.ProfileQueries
  alias Tymeslot.ThemeCustomizations
  alias Tymeslot.Webhooks

  @spec run() :: term()
  def run do
    {:ok, _unused} = Application.ensure_all_started(:tymeslot)
    File.rm("/tmp/booking-owners.txt")
    Brands.reload()

    Enum.each(brands_to_seed(), &seed_brand/1)

    if System.get_env("SEED_SAMPLE_MAIL") == "true" and
         not File.exists?("/tmp/booking-samples-sent") do
      deliver_samples()
      File.write!("/tmp/booking-samples-sent", "ok")
    end

    :ok
  end

  @spec deliver_samples() :: term()
  def deliver_samples do
    Delivery.allow_outside_job(fn ->
      Enum.each(brands_to_seed(), &deliver_sample/1)
    end)
  end

  # BookDesk24 is the optional second tenant and stays disabled until its
  # domain is bought. Production does not register that owner. Provisioning
  # itself sends no verification mail; a queued "Verify your email" is what
  # reached host@scheduler24.io after the account was already verified.
  defp brands_to_seed do
    if neutral_seed?(),
      do: Brands.enabled(),
      else: Enum.filter(Brands.enabled(), & &1.house_brand)
  end

  defp neutral_seed? do
    System.get_env("SEED_NEUTRAL_TENANT") in ["true", "1", "yes"]
  end

  defp seed_brand(brand) do
    Brands.bind(brand)
    password = password_for(brand)
    user = ensure_user(brand, password)
    remember(brand, password)
    profile = Profiles.get_profile(user.id)
    profile = profile_fields(profile, brand)
    maybe_avatar(profile, brand)
    theme(profile, brand)
    hours(profile, brand)
    Enum.each(brand.events, &ensure_event(user, brand, &1))
    hide_blank_slugs(user)
    maybe_calendar(user, brand)
    maybe_webhook(user, brand)
    persist_document(brand)
    Logger.info("brand seeded", brand: brand.key, username: brand.username)
  rescue
    error ->
      Logger.error("brand seed failed", brand: brand.key, error: Exception.message(error))
      reraise error, __STACKTRACE__
  end

  defp ensure_user(brand, password) do
    case BrandSeedQueries.user_by_email(brand.owner_email) do
      %Auth.UserSchema{} = user ->
        mark_ready(user, brand)
        user

      nil ->
        case Auth.register_user(
               %{"email" => brand.owner_email, "password" => password},
               via: :provisioning,
               ip: {127, 0, 0, 1}
             ) do
          {:ok, user, _message} ->
            {:ok, user} = mark_ready(user, brand)
            user

          other ->
            raise "could not register #{brand.owner_email}: #{inspect(other)}"
        end
    end
  end

  defp mark_ready(user, brand) do
    now = DateTime.utc_now(:second)

    BrandSeedQueries.mark_ready(user, %{
      verified_at: user.verified_at || now,
      onboarding_completed_at: user.onboarding_completed_at || now,
      is_admin: user.is_admin || brand.house_brand
    })
  end

  defp profile_fields(profile, brand) do
    {:ok, profile} =
      BrandSeedQueries.update_profile(profile, %{
        full_name: brand.owner_name,
        timezone: brand.timezone
      })

    {:ok, profile} = ProfileQueries.update_username(profile, brand.username)

    copy = brand.copy["en"] || %{}

    {:ok, profile} =
      ProfileQueries.update_intro(profile, %{
        headline: copy["hero"],
        bio: copy["bio"]
      })

    legal = brand.legal || %{}

    {:ok, profile} =
      ProfileQueries.update_legal_links(profile, %{
        legal_notice_url: blank_nil(legal["notice"]),
        privacy_policy_url: blank_nil(legal["privacy"])
      })

    Profiles.update_booking_theme(profile, "4")
    Profiles.get_profile(profile.user_id)
  end

  defp maybe_avatar(profile, %{portrait: true, house_brand: true}) do
    path = Application.app_dir(:tymeslot, "priv/seed/markus-froehlich.jpg")

    if profile.avatar in [nil, ""] and File.exists?(path) do
      case Avatars.update_avatar(profile, %{path: path, client_name: "markus-froehlich.jpg"}) do
        {:ok, _unused} -> :ok
        other -> Logger.warning("avatar not stored", reason: LogFormat.reason(other))
      end
    end
  end

  defp maybe_avatar(_profile, _brand), do: :ok

  defp theme(profile, brand) do
    scheme = if brand.layout == "sales_room", do: "ink", else: "ivory"

    ThemeCustomizations.upsert_theme_customization(profile.id, "4", %{
      "color_scheme" => scheme,
      "font" => "classic",
      "radius" => "soft"
    })
  rescue
    error -> Logger.warning("theme defaults kept", error: Exception.message(error))
  end

  defp hours(profile, brand) do
    schedule = AvailabilityScheduleQueries.get_default(profile.id)
    availability = brand.availability || %{}

    AvailabilityScheduleQueries.update_policy(schedule, %{
      buffer_before_minutes: availability["buffer_before"] || 15,
      buffer_after_minutes: availability["buffer_after"] || 15,
      min_advance_hours: availability["min_notice_hours"] || 24
    })

    days = availability["days"] || %{}

    Enum.each(days, fn {day, [start_t, end_t]} ->
      AvailabilityActions.update_day_hours(
        profile.id,
        schedule.id,
        String.to_integer(day),
        start_t,
        end_t
      )
    end)

    Enum.each(availability["closed"] || [], fn day ->
      WeeklySchedule.upsert_day_availability(schedule.id, day, %{is_available: false})
    end)
  end

  defp ensure_event(user, brand, event) do
    existing = BrandSeedQueries.meeting_type(user.id, event["slug"], event["name"])

    availability = brand.availability || %{}
    location = if brand.house_brand, do: "Google Meet", else: "Video call"

    attrs = %{
      user_id: user.id,
      name: event["name"],
      description: event["description"],
      duration_minutes: event["minutes"],
      is_active: true,
      is_private: event["private"] == true,
      slug: event["slug"],
      buffer_before_minutes: availability["buffer_before"] || 15,
      buffer_after_minutes: availability["buffer_after"] || 15,
      min_advance_hours: availability["min_notice_hours"] || 24,
      custom_fields: questions(event["questions"] || []),
      locations: [
        %{"kind" => "custom", "label" => location, "details" => location, "position" => 0}
      ]
    }

    result =
      cond do
        is_nil(existing) ->
          MeetingTypes.create_meeting_type(attrs)

        existing.slug == event["slug"] and existing.is_active ->
          {:ok, existing}

        true ->
          MeetingTypes.update_meeting_type(existing, attrs)
      end

    case result do
      {:ok, _unused} ->
        :ok

      other ->
        Logger.error("meeting type not saved",
          slug: event["slug"],
          reason: LogFormat.reason(other)
        )

        other
    end
  end

  defp questions(list) do
    list
    |> Enum.with_index()
    |> Enum.map(fn {label, index} ->
      %{
        "id" => "q#{index + 1}",
        "type" => "short_text",
        "label" => label,
        "required" => true,
        "position" => index
      }
    end)
  end

  defp hide_blank_slugs(user) do
    BrandSeedQueries.deactivate_blank_slugs(user.id)
  end

  defp maybe_calendar(user, brand) do
    if System.get_env("SPV_DEMO_CALENDAR") == "true" do
      name = if brand.house_brand, do: "Demo calendar", else: "Example calendar"

      Management.insert_integration(%{
        user_id: user.id,
        name: name,
        provider: "demo",
        is_active: true,
        base_url: "https://demo.localhost",
        provider_account_email: brand.owner_email
      })
    end
  rescue
    error ->
      Logger.warning("demo calendar skipped", brand: brand.key, error: Exception.message(error))
  end

  defp maybe_webhook(user, brand) do
    env = brand.webhook_url_env || ""

    case System.get_env(env) do
      url when is_binary(url) and url != "" ->
        Webhooks.create_webhook(user.id, %{
          name: "Bookings",
          url: url,
          events: ["booking.created"]
        })

      _unused ->
        :ok
    end
  rescue
    error -> Logger.warning("webhook not created", error: Exception.message(error))
  end

  defp persist_document(brand) do
    path = Path.join(Application.app_dir(:tymeslot, "priv/brands"), brand.key <> ".json")

    with {:ok, body} <- File.read(path),
         {:ok, _stored} <- BrandSeedQueries.insert_document(brand.key, body) do
      :ok
    else
      _reason -> :ok
    end
  rescue
    error ->
      Logger.warning("brand document not stored", error: Exception.message(error))
      :ok
  end

  defp deliver_sample(brand) do
    Brands.bind(brand)

    mjml =
      Layouts.system_layout(
        "<mj-text>Your time is confirmed. A calendar invitation is attached to the real booking mail.</mj-text>",
        intent: :confirmed,
        eyebrow: "Confirmed",
        title: "Your booking",
        stage_title: "You are booked",
        preview: "Your time is confirmed."
      )

    html = MjmlEmail.compile_mjml(mjml)

    text = """
    You are booked.

    #{Brands.footer_label()}
    """

    email =
      Email.new()
      |> Email.to({"Guest", "guest@example.com"})
      |> Email.from({MjmlEmail.fetch_from_name(), MjmlEmail.fetch_from_email()})
      |> Email.subject("Confirmed: #{brand.name}")
      |> Email.html_body(html)
      |> Email.text_body(text)
      |> MjmlEmail.attach_logo()

    case Delivery.deliver(email) do
      {:ok, _unused} ->
        assert_private!(brand, html <> text)
        Logger.info("sample mail accepted", brand: brand.key)

      other ->
        Logger.error("sample mail failed", brand: brand.key, reason: LogFormat.reason(other))
    end

    ics =
      IcsGenerator.generate_ics(%{
        title: "Intro call",
        description: "A short first call.",
        start_time: DateTime.utc_now(:second),
        end_time: DateTime.add(DateTime.utc_now(:second), 1800, :second),
        organizer_name: brand.owner_name,
        organizer_email: brand.owner_email,
        organizer_user_id: nil,
        attendee_email: "guest@example.com",
        uid: "sample-#{brand.key}"
      })

    assert_private!(brand, ics)
  end

  defp assert_private!(%{house_brand: true}, _body), do: :ok

  defp assert_private!(brand, body) do
    body = Brands.scrub(body, brand)

    if Brands.leak?(body) do
      snippet =
        Regex.scan(~r/.{0,40}(scalepoint|tymeslot|\bspv\b).{0,40}/i, body)
        |> Enum.map(&hd/1)
        |> Enum.take(3)
        |> Enum.join(" | ")

      raise "neutral tenant #{brand.key} leaked a house or upstream name: #{snippet}"
    else
      :ok
    end
  end

  defp password_for(%{house_brand: true}), do: password("SPV_OWNER_PASSWORD")
  defp password_for(_unused), do: password("NEUTRAL_OWNER_PASSWORD")

  defp password(env) do
    case System.get_env(env) do
      value when is_binary(value) and byte_size(value) >= 12 -> value
      _unused -> Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
    end
  end

  defp remember(brand, password) do
    line = "#{brand.key} #{brand.owner_email} #{password}\n"
    File.write!("/tmp/booking-owners.txt", line, [:append])
  end

  defp blank_nil(""), do: nil
  defp blank_nil(value), do: value
end
