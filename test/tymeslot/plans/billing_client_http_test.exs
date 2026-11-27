defmodule Tymeslot.Plans.BillingClientHTTPTest do
  use Tymeslot.DataCase, async: false

  @moduletag :payments

  import Mox
  import Tymeslot.ConfigTestHelpers
  import Tymeslot.Factory

  alias Tymeslot.Plans
  alias Tymeslot.Plans.AccountDeletionHook
  alias Tymeslot.Plans.Billing
  alias Tymeslot.Plans.BillingClient.HTTP
  alias Tymeslot.Plans.PortalLink
  alias Tymeslot.Plans.UserRegisteredHook
  alias Tymeslot.Plans.Workers.EntitlementResync

  setup :verify_on_exit!

  setup do
    with_config(:tymeslot,
      billing_client: HTTP,
      plans_enabled: true,
      plans: [
        billing_url: "https://billing.test",
        billing_api_key: "test-key",
        webhook_secret: "unit-test-connect-secret",
        past_due_grace_days: 7,
        trial_days: 14
      ]
    )

    :ok
  end

  test "checkout sends the booking price, absolute return urls, and mode confirm" do
    user = insert(:user, locale: "de")

    expect(Tymeslot.HTTPClientMock, :request, fn :post, url, body, headers, _opts ->
      assert url == "https://billing.test/v1/checkout-sessions"
      assert {"authorization", "Bearer test-key"} in headers
      decoded = Jason.decode!(body)
      assert decoded["product"] == "booking"
      assert decoded["price_lookup_key"] == "booking_pro_yearly"
      assert decoded["external_user_id"] == "booking:#{user.id}"
      assert decoded["email"] == user.email
      assert decoded["locale"] == "de"

      assert decoded["success_url"] ==
               "https://book.scalepoint-ventures.com/welcome?checkout=success"

      assert decoded["cancel_url"] == "https://book.scalepoint-ventures.com/dashboard/plan"
      refute String.contains?(decoded["cancel_url"], "?")

      {:ok,
       %{status: 200, body: %{"url" => "https://billing.test/confirm/1", "mode" => "confirm"}}}
    end)

    assert {:ok, %{url: "https://billing.test/confirm/1", mode: "confirm"}} =
             HTTP.create_checkout(user, "year", %{success: "/welcome", cancel: "/plan?x=1"})
  end

  test "checkout mode noop has no url and monthly uses the monthly price" do
    user = insert(:user)

    expect(Tymeslot.HTTPClientMock, :request, fn :post, _url, body, _headers, _opts ->
      assert Jason.decode!(body)["price_lookup_key"] == "booking_pro_monthly"
      {:ok, %{status: 200, body: %{"url" => nil, "mode" => "noop"}}}
    end)

    assert {:ok, %{mode: "noop"}} = HTTP.create_checkout(user, "month", %{})
  end

  test "register posts a trial and an optional organisation, and keeps the account id" do
    user = insert(:user, locale: "de", name: "Ada")

    expect(Tymeslot.HTTPClientMock, :request, fn :post, url, body, headers, _opts ->
      assert url == "https://billing.test/v1/accounts"
      assert {"authorization", "Bearer test-key"} in headers
      decoded = Jason.decode!(body)
      assert decoded["trial"] == true
      assert decoded["product"] == "booking"
      assert decoded["external_user_id"] == "booking:#{user.id}"
      assert decoded["locale"] == "de"
      assert decoded["name"] == "Ada"
      assert decoded["organisation_id"] == "org_1"
      assert decoded["email"] == user.email
      refute Map.has_key?(decoded, "test_clock")

      {:ok,
       %{
         status: 201,
         body: %{
           "account_id" => "acc_1",
           "organisation_id" => "org_1",
           "version" => 2,
           "data" => %{
             "external_user_id" => "booking:#{user.id}",
             "plan" => "pro",
             "status" => "trialing",
             "billing_account_ref" => "acc_1"
           }
         }
       }}
    end)

    assert :ok =
             UserRegisteredHook.on_user_registered(user.id, %{"organisation_id" => "org_1"})

    row = Plans.get_entitlement(user.id)
    assert row.plan == "pro"
    assert row.status == "trialing"
    assert row.billing_account_ref == "acc_1"
    assert row.source_version == 2
  end

  test "a repeated account registration is success" do
    user = insert(:user)

    expect(Tymeslot.HTTPClientMock, :request, fn :post, url, _body, _headers, _opts ->
      assert url == "https://billing.test/v1/accounts"
      {:ok, %{status: 409, body: %{"error" => "conflict"}}}
    end)

    assert :ok = UserRegisteredHook.on_user_registered(user.id, %{})
    assert Plans.get_entitlement(user.id).status == "trialing"
  end

  test "account deletion cancels immediately and a missing account is success" do
    user = insert(:user)

    expect(Tymeslot.HTTPClientMock, :request, fn :post, url, body, _headers, _opts ->
      assert url == "https://billing.test/v1/accounts/booking:#{user.id}/cancel"
      decoded = Jason.decode!(body)
      assert decoded["product"] == "booking"
      assert decoded["reason"] == "account_deleted"
      assert decoded["at_period_end"] == false
      {:ok, %{status: 200, body: %{"plan" => "free"}}}
    end)

    assert :ok =
             AccountDeletionHook.on_account_deletion(user.id)

    expect(Tymeslot.HTTPClientMock, :request, fn :post, url, _body, _headers, _opts ->
      assert url == "https://billing.test/v1/accounts/booking:#{user.id}/cancel"
      {:ok, %{status: 404, body: %{}}}
    end)

    assert :ok = HTTP.cancel(user.id, reason: "account_deleted", at_period_end: false)
  end

  test "portal sessions use the external user id and an https return url" do
    user = insert(:user)

    expect(Tymeslot.HTTPClientMock, :request, fn :post, url, body, _headers, _opts ->
      assert url == "https://billing.test/v1/portal-sessions"
      decoded = Jason.decode!(body)
      assert decoded["product"] == "booking"
      assert decoded["external_user_id"] == "booking:#{user.id}"
      assert decoded["return_url"] == "https://book.scalepoint-ventures.com/dashboard/plan"
      {:ok, %{status: 200, body: %{"url" => "https://billing.stripe.com/session"}}}
    end)

    assert {:ok, %{url: "https://billing.stripe.com/session"}} =
             HTTP.create_portal(user, "/dashboard/plan")
  end

  test "the signed portal link matches the published vector and stays within 14 days" do
    sig = PortalLink.sign("connect", "acc_1", 2_000_000_000, "unit-test-connect-secret")
    assert sig == "8f9447d0fb3a84b42e10210ccd4d6cd1096cd4674d2a4805258fc4ad748a4deb"

    assert {:ok, url} = PortalLink.build("acc_9", ttl: 30 * 86_400)
    assert url =~ "https://billing.test/portal?"
    assert url =~ "a=acc_9"
    assert url =~ "m=booking"
    refute url =~ "unit-test-connect-secret"

    exp = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("exp")
    {parsed, ""} = Integer.parse(exp)
    assert parsed - System.system_time(:second) <= 14 * 86_400
  end

  test "resync reads the entitlement and ignores an unknown account" do
    user = insert(:user)

    expect(Tymeslot.HTTPClientMock, :request, fn :get, url, "", headers, _opts ->
      assert {"authorization", "Bearer test-key"} in headers
      uri = URI.parse(url)
      assert uri.path == "/v1/entitlements"

      assert URI.decode_query(uri.query) == %{
               "product" => "booking",
               "external_user_id" => "booking:#{user.id}"
             }

      {:ok,
       %{
         status: 200,
         body: %{
           "version" => 4,
           "data" => %{
             "external_user_id" => "booking:#{user.id}",
             "plan" => "pro",
             "status" => "active"
           }
         }
       }}
    end)

    assert :ok = EntitlementResync.perform(struct(Oban.Job, args: %{"user_id" => user.id}))
    row = Plans.get_entitlement(user.id)
    assert row.plan == "pro"
    assert row.status == "active"
    assert row.source_version == 4

    expect(Tymeslot.HTTPClientMock, :request, fn :get, _url, "", _headers, _opts ->
      {:ok, %{status: 404, body: %{"error" => "unknown"}}}
    end)

    assert :ok = EntitlementResync.perform(struct(Oban.Job, args: %{"user_id" => user.id}))
    assert Plans.get_entitlement(user.id).source_version == 4
  end

  test "healthz 2xx marks billing reachable" do
    expect(Tymeslot.HTTPClientMock, :request, fn :get, url, "", headers, _opts ->
      assert url == "https://billing.test/healthz"
      refute Enum.any?(headers, fn {name, _value} -> name == "authorization" end)
      {:ok, %{status: 200, body: %{"ok" => true, "livemode" => false}}}
    end)

    assert Billing.healthy?()
  end

  test "healthz that does not answer keeps the unavailable path" do
    refute Billing.healthy?()
  end

  test "register asks for a test clock only when the test-run flag is on" do
    user = insert(:user)

    with_config(:tymeslot,
      plans: [
        billing_url: "https://billing.test",
        billing_api_key: "test-key",
        webhook_secret: "unit-test-connect-secret",
        past_due_grace_days: 7,
        trial_days: 14,
        billing_test_clock: true
      ]
    )

    expect(Tymeslot.HTTPClientMock, :request, fn :post, url, body, _headers, _opts ->
      assert url == "https://billing.test/v1/accounts"
      assert Jason.decode!(body)["test_clock"] == true
      {:ok, %{status: 409, body: %{}}}
    end)

    assert :ok = HTTP.register_account(%{id: user.id, email: user.email, locale: "en"})
  end
end
