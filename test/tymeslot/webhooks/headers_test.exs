defmodule Tymeslot.Webhooks.HeadersTest do
  use ExUnit.Case, async: true

  @moduletag :webhooks

  alias Tymeslot.Webhooks.Headers

  test "current names use the BookDesk24 prefix" do
    assert Headers.token() == "X-BookDesk24-Token"
    assert Headers.signature() == "X-BookDesk24-Signature"
    assert Headers.timestamp() == "X-BookDesk24-Timestamp"
    assert Headers.delivery_id() == "X-BookDesk24-Delivery-Id"
    assert Headers.user_agent() == "BookDesk24-Webhooks/1.0"
  end

  test "legacy token headers are still treated as sensitive" do
    assert Headers.sensitive_token?("X-BookDesk24-Token")
    assert Headers.sensitive_token?("x-bookdesk24-token")
    assert Headers.sensitive_token?("X-Tymeslot-Token")
    assert Headers.sensitive_token?("X-the scheduler-Token")
    assert Headers.sensitive_token?("X-the-scheduler-Token")
    refute Headers.sensitive_token?("X-BookDesk24-Signature")
    refute Headers.sensitive_token?("Content-Type")
  end
end
