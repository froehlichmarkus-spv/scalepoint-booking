defmodule TymeslotWeb.GrowthOsBillingChainTest do
  @moduledoc """
  The automated BookDesk24 plan chain, driven only by signed growth-os-billing
  pushes to `POST /webhooks/growth-os-billing`: signup trial, checkout,
  dunning with grace, restriction, reactivation, cancel at period end, and
  the trial that ends without a payment.

  The payloads are the shape billing's `entitlements.native("booking", ...)`
  sends, including how it maps its own `read_only` state: `past_due` with a
  `grace_until` in the past after failed payments, and `canceled` with plan
  `free` when a trial or subscription has ended.
  """

  use TymeslotWeb.ConnCase, async: false

  @moduletag :payments
  @moduletag :controllers

  import Tymeslot.ConfigTestHelpers
  import Tymeslot.Factory

  alias Tymeslot.Plans
  alias Tymeslot.Plans.AccessChecker

  @secret "chain-webhook-secret"

  setup do
    with_config(:tymeslot,
      plans_enabled: true,
      feature_access_checker: AccessChecker,
      plans: [
        past_due_grace_days: 7,
        trial_days: 14,
        comped_user_emails: [],
        oauth_video_providers: [:google_meet, :zoom, :teams],
        webhook_secret: @secret
      ]
    )

    user = insert(:user)
    insert(:profile, user: user)
    %{user: user}
  end

  test "signup trial to reactivation runs on billing pushes alone", %{conn: conn, user: user} do
    # 1. Signup: the registration hook opens the local trial before billing answers.
    assert {:ok, _trial} = Plans.start_local_trial(user.id)
    assert plan(user) == :pro

    # 2. Billing confirms the trial.
    assert push(conn, user, 1, %{
             "plan" => "pro",
             "status" => "trialing",
             "trial_ends_at" => in_days(14)
           }) == 200

    assert plan(user) == :pro

    # 3. Checkout paid.
    assert push(conn, user, 2, %{
             "plan" => "pro",
             "status" => "active",
             "interval" => "month",
             "current_period_end" => in_days(30)
           }) == 200

    assert plan(user) == :pro

    # 4. Payment failed: dunning with grace keeps Pro and shows the notice.
    assert push(conn, user, 3, %{
             "plan" => "pro",
             "status" => "past_due",
             "grace_until" => in_days(7)
           }) ==
             200

    assert plan(user) == :pro
    assert Plans.get_entitlement(user.id).status == "past_due"

    # 5. Grace over: billing's read_only arrives as past_due with a past grace_until.
    assert push(conn, user, 4, %{
             "plan" => "pro",
             "status" => "past_due",
             "grace_until" => in_days(-1)
           }) ==
             200

    assert plan(user) == :free
    assert Plans.features(plan(user)).polls_allowed == false
    assert Plans.limits(plan(user)).meeting_types == 1

    # 6. Reactivation after paying.
    assert push(conn, user, 5, %{
             "plan" => "pro",
             "status" => "active",
             "interval" => "month",
             "current_period_end" => in_days(30)
           }) == 200

    assert plan(user) == :pro

    # 7. Cancel at period end keeps Pro until the period ends.
    assert push(conn, user, 6, %{
             "plan" => "pro",
             "status" => "active",
             "cancel_at_period_end" => true,
             "current_period_end" => in_days(10)
           }) == 200

    assert plan(user) == :pro
    assert Plans.get_entitlement(user.id).cancel_at_period_end

    # 8. Period ended.
    assert push(conn, user, 7, %{
             "plan" => "free",
             "status" => "canceled",
             "grace_until" => in_days(7)
           }) ==
             200

    assert plan(user) == :free
  end

  test "a trial that ends without payment falls back to Free", %{conn: conn, user: user} do
    assert {:ok, _trial} = Plans.start_local_trial(user.id)
    assert plan(user) == :pro

    assert push(conn, user, 1, %{
             "plan" => "free",
             "status" => "canceled",
             "trial_ends_at" => in_days(-1)
           }) ==
             200

    assert plan(user) == :free
  end

  test "a replayed or older push keeps the newer state", %{conn: conn, user: user} do
    active = %{"plan" => "pro", "status" => "active", "current_period_end" => in_days(30)}
    assert push(conn, user, 5, active) == 200
    assert push(conn, user, 5, active) == 200

    assert push(conn, user, 4, %{
             "plan" => "pro",
             "status" => "past_due",
             "grace_until" => in_days(-1)
           }) ==
             200

    assert plan(user) == :pro
    assert Plans.get_entitlement(user.id).source_version == 5
  end

  test "an unsigned or wrongly signed push changes nothing", %{conn: conn, user: user} do
    body = payload(user, 9, %{"plan" => "pro", "status" => "active"})

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-gos-timestamp", now())
      |> put_req_header("x-gos-signature", "v1=" <> String.duplicate("0", 64))
      |> assign(:raw_body, body)
      |> post("/webhooks/growth-os-billing", body)

    assert conn.status == 400
    assert Plans.get_entitlement(user.id) == nil
  end

  defp push(conn, user, version, data) do
    body = payload(user, version, data)
    ts = now()
    mac = Base.encode16(:crypto.mac(:hmac, :sha256, @secret, "#{ts}.#{body}"), case: :lower)

    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-gos-timestamp", ts)
    |> put_req_header("x-gos-signature", "v1=" <> mac)
    |> put_req_header("x-growth-os-signature", "t=#{ts},v1=#{mac}")
    |> assign(:raw_body, body)
    |> post("/webhooks/growth-os-billing", body)
    |> Map.fetch!(:status)
  end

  defp payload(user, version, data) do
    Jason.encode!(%{
      "id" => "evt_gos_acc_chain_#{user.id}_#{version}",
      "type" => "entitlement.updated",
      "version" => version,
      "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
      "data" =>
        Map.merge(
          %{
            "external_user_id" => "booking:#{user.id}",
            "interval" => nil,
            "trial_ends_at" => nil,
            "current_period_end" => nil,
            "cancel_at_period_end" => false,
            "grace_until" => nil,
            "billing_account_ref" => "org_chain"
          },
          data
        )
    })
  end

  defp plan(user) do
    Plans.invalidate(user.id)
    Plans.effective_plan(user.id)
  end

  defp in_days(days) do
    DateTime.utc_now() |> DateTime.add(days * 86_400, :second) |> DateTime.to_iso8601()
  end

  defp now, do: Integer.to_string(System.system_time(:second))
end
