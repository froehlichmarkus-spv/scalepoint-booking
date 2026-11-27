defmodule Tymeslot.PlansTest do
  use Tymeslot.DataCase, async: false

  @moduletag :payments

  import Tymeslot.ConfigTestHelpers
  import Tymeslot.Factory

  alias Tymeslot.Brands

  alias Tymeslot.Integrations.Calendar.Management
  alias Tymeslot.MeetingTypes
  alias Tymeslot.Plans
  alias Tymeslot.Plans.AccessChecker
  alias Tymeslot.Plans.BookingChrome
  alias Tymeslot.Plans.Entitlement
  alias Tymeslot.Plans.PlanAccess
  alias Tymeslot.Plans.Webhook
  alias Tymeslot.Repo
  alias Tymeslot.ThemeCustomizations.Tokens

  setup do
    with_config(:tymeslot,
      plans_enabled: true,
      feature_access_checker: AccessChecker,
      meeting_payments_enabled: true,
      plans: [
        past_due_grace_days: 7,
        trial_days: 14,
        comped_user_emails: [],
        oauth_video_providers: [:google_meet, :zoom, :teams],
        webhook_secret: "test-webhook-secret"
      ]
    )

    user = insert(:user)
    insert(:profile, user: user)
    %{user: user}
  end

  test "brand tokens file matches the Growth OS contract" do
    Brands.reload()
    assert Brands.product_name() == "BookDesk24"
    css = File.read!(Path.expand("brand/tokens.css"))

    assert css =~
             ":root{--spv-navy:#111E32;--spv-navy-dark:#09101B;--spv-navy-light:#1C2B40;--spv-teal:#469189;--spv-teal-strong:#3A7872;--spv-teal-light:#6BC7BE;--spv-text-light:#F3F5F7;--spv-muted:#65758B;--spv-white:#FFFFFF;--spv-logo-navy:#012148;--spv-font-ui:'Inter',system-ui,sans-serif;--spv-font-display:'DM Serif Display',Georgia,serif;--spv-radius:8px;}"
  end

  test "the house brand exposes both product names" do
    Brands.reload()
    brand = Brands.neutral_default()
    assert Brands.product_name(brand) == "BookDesk24"
    assert Brands.suite_name(brand) == "ScalePoint Ventures Growth OS"
    assert Brands.module_name(brand) == "Booking"
    assert Brands.suite_title(brand) == "ScalePoint Growth OS · Booking"
    assert Brands.byline(brand) == "by ScalePoint"
  end

  test "a missing entitlement is free and a local trial is pro", %{user: user} do
    assert Plans.effective_plan(user.id) == :free
    assert {:ok, _trial} = Plans.start_local_trial(user.id)
    Plans.invalidate(user.id)
    assert Plans.effective_plan(user.id) == :pro
    assert {:ok, _again} = Plans.start_local_trial(user.id)
    assert length(Repo.all(Entitlement)) == 1
  end

  test "an older source version does not overwrite a newer entitlement", %{user: user} do
    assert {:ok, _saved} =
             Plans.upsert_entitlement(%{
               "data" => %{
                 "external_user_id" => "booking:#{user.id}",
                 "plan" => "pro",
                 "status" => "active"
               },
               "version" => 5
             })

    assert {:ok, row} =
             Plans.upsert_entitlement(%{
               "data" => %{
                 "external_user_id" => "booking:#{user.id}",
                 "plan" => "free",
                 "status" => "canceled"
               },
               "version" => 4
             })

    assert row.plan == "pro"
    assert row.source_version == 5
    Plans.invalidate(user.id)
    assert Plans.effective_plan(user.id) == :pro
  end

  test "free cannot take pro features and pro without connect needs stripe", %{user: user} do
    assert AccessChecker.check_access(user.id, :group_bookings_allowed) == {:error, :pro_required}
    assert AccessChecker.check_access(user.id, :polls_allowed) == {:error, :pro_required}
    assert AccessChecker.check_access(user.id, :reminders_allowed) == {:error, :pro_required}
    assert AccessChecker.check_access(user.id, :oauth_video_allowed) == {:error, :pro_required}
    assert AccessChecker.check_access(user.id, :meeting_payments) == {:error, :pro_required}
    assert AccessChecker.check_access(user.id, :custom_questions_allowed) == :ok
    assert AccessChecker.check_access(user.id, :some_future_feature) == :ok

    {:ok, _saved} =
      Plans.upsert_entitlement(%{
        "data" => %{
          "external_user_id" => "booking:#{user.id}",
          "plan" => "pro",
          "status" => "active"
        },
        "version" => 1
      })

    Plans.invalidate(user.id)
    assert AccessChecker.check_access(user.id, :group_bookings_allowed) == :ok
    assert AccessChecker.check_access(user.id, :meeting_payments) == {:error, :stripe_required}

    insert(:connect_account, user: user, charges_enabled: true, default_currency: "eur")
    assert AccessChecker.check_access(user.id, :meeting_payments) == :ok
  end

  test "free can create one event type and one calendar, not a second", %{user: user} do
    assert {:ok, _type} = MeetingTypes.create_meeting_type(type_attrs(user, "Intro"))

    assert {:error, :quota_exceeded} =
             MeetingTypes.create_meeting_type(type_attrs(user, "Follow-up"))

    assert {:ok, first} = Management.insert_integration(caldav_attrs(user, "first"))
    assert {:error, :quota_exceeded} = Management.insert_integration(caldav_attrs(user, "second"))
    assert {:ok, _reconnected} = Management.reconnect_integration(first, %{name: "first"})
  end

  test "downgrade pauses every active type except the oldest bookable one", %{user: user} do
    older =
      insert(:meeting_type, user: user, name: "Older", inserted_at: ~U[2026-01-01 00:00:00Z])

    newer =
      insert(:meeting_type, user: user, name: "Newer", inserted_at: ~U[2026-06-01 00:00:00Z])

    offered = PlanAccess.reject_paused([newer, older])
    assert Enum.map(offered, & &1.id) == [older.id]
    assert PlanAccess.paused?(newer)
    refute PlanAccess.paused?(older)
    assert PlanAccess.ensure_bookable(%{meeting_type: newer}) == {:error, :plan_paused}
  end

  test "pro keeps a custom logo and accent, free does not", %{user: user} do
    tokens = %Tokens{
      vars: %{"--theme-primary" => "#112233"},
      media: %{logo: %{src: "/uploads/logo.png"}}
    }

    customization = %{settings: %{"accent" => "#112233"}}
    free = BookingChrome.present(user.id, customization, tokens)
    refute free.media[:logo]
    refute free.vars["--spv-teal"]

    {:ok, _saved} =
      Plans.upsert_entitlement(%{
        "data" => %{
          "external_user_id" => "booking:#{user.id}",
          "plan" => "pro",
          "status" => "active"
        },
        "version" => 2
      })

    Plans.invalidate(user.id)
    pro = BookingChrome.present(user.id, customization, tokens)
    assert pro.media[:logo]
    assert pro.vars["--spv-teal"] == "#112233"
    assert String.starts_with?(pro.vars["--spv-teal-strong"], "#")
  end

  test "webhook rejects a bad signature and ignores an older replay", %{user: user} do
    body =
      Jason.encode!(%{
        "id" => "evt_1",
        "type" => "entitlement.updated",
        "version" => 3,
        "data" => %{
          "external_user_id" => "booking:#{user.id}",
          "plan" => "pro",
          "status" => "active"
        }
      })

    assert Webhook.verify(body, timestamp(), "v1=deadbeef") == {:error, :invalid_signature}

    {ts, signature} = sign(body)
    assert Webhook.verify(body, ts, signature) == :ok
    assert {:ok, entitlement} = Webhook.process(body)
    assert entitlement.plan == "pro"

    assert {:ok, :duplicate} = Plans.ingest_event(Jason.decode!(body))

    older = %{
      "id" => "evt_0",
      "type" => "entitlement.updated",
      "version" => 1,
      "data" => %{
        "external_user_id" => "booking:#{user.id}",
        "plan" => "free",
        "status" => "canceled"
      }
    }

    assert {:ok, kept} = Plans.ingest_event(older)
    assert kept.plan == "pro"
  end

  test "webhook accepts the signature inside five minutes and rejects a replay" do
    body = "{}"
    now = System.system_time(:second)
    fresh = signature(body, now)
    assert Webhook.verify(body, Integer.to_string(now), fresh) == :ok

    stale = now - 301

    assert Webhook.verify(body, Integer.to_string(stale), signature(body, stale)) ==
             {:error, :invalid_signature}

    {ts, sig} = Webhook.signature_headers(nil, nil, "t=#{now},v1=#{hex(body, now)}")
    assert Webhook.verify(body, ts, sig) == :ok
  end

  test "past_due after grace and canceled are free", %{user: user} do
    past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_iso8601()

    assert {:ok, _saved} =
             Plans.upsert_entitlement(%{
               "version" => 2,
               "data" => %{
                 "external_user_id" => "booking:#{user.id}",
                 "plan" => "pro",
                 "status" => "past_due",
                 "grace_until" => past
               }
             })

    Plans.invalidate(user.id)
    assert Plans.effective_plan(user.id) == :free

    future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()

    assert {:ok, _kept} =
             Plans.upsert_entitlement(%{
               "version" => 3,
               "data" => %{
                 "external_user_id" => "booking:#{user.id}",
                 "plan" => "pro",
                 "status" => "past_due",
                 "grace_until" => future
               }
             })

    Plans.invalidate(user.id)
    assert Plans.effective_plan(user.id) == :pro

    assert {:ok, _canceled} =
             Plans.upsert_entitlement(%{
               "version" => 4,
               "data" => %{
                 "external_user_id" => "booking:#{user.id}",
                 "plan" => "pro",
                 "status" => "canceled"
               }
             })

    Plans.invalidate(user.id)
    assert Plans.effective_plan(user.id) == :free
  end

  defp type_attrs(user, name),
    do: %{name: name, duration_minutes: 30, user_id: user.id}

  defp caldav_attrs(user, name) do
    %{
      user_id: user.id,
      name: name,
      provider: "caldav",
      base_url: "https://dav.example.com",
      username: name,
      password: "secret",
      provider_account_id: "https://dav.example.com||#{name}",
      calendar_paths: ["/dav/#{name}"],
      is_active: true
    }
  end

  defp timestamp, do: Integer.to_string(System.system_time(:second))

  defp sign(body) do
    ts = timestamp()
    {ts, signature(body, String.to_integer(ts))}
  end

  defp signature(body, ts), do: "v1=" <> hex(body, ts)

  defp hex(body, ts) do
    mac = :crypto.mac(:hmac, :sha256, "test-webhook-secret", "#{ts}.#{body}")
    Base.encode16(mac, case: :lower)
  end
end
