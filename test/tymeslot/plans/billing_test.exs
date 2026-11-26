defmodule Tymeslot.Plans.BillingTest do
  use ExUnit.Case, async: true

  @moduledoc """
  The dashboard talks to growth-os-billing through one module. When that
  service cannot be reached, the sentence is informal German.
  """

  @moduletag :payments
  @moduletag :unit

  alias Tymeslot.Plans.Billing
  alias TymeslotWeb.ErrorHTML

  test "an unreachable billing service gets a branded informal German sentence" do
    message = Billing.unavailable_message()

    assert message =~ "BookDesk24"
    assert message =~ ErrorHTML.support_email()
    assert message =~ "Versuch es später noch einmal"
    refute message =~ "Billing is unavailable"
    refute message =~ "Sie "
  end

  test "checkout returns to the public welcome page and a query-free cancel url" do
    urls = Billing.checkout_urls()
    assert urls.success == "https://book.scalepoint-ventures.com/welcome"
    assert urls.cancel == "https://book.scalepoint-ventures.com/dashboard/plan"
    assert Billing.portal_return_url() == "https://book.scalepoint-ventures.com/dashboard/plan"
  end

  test "a failed pro-rata charge is explained in informal German and English" do
    message = Billing.payment_failed_message()
    assert message =~ "Die Zahlung ist nicht durchgegangen"
    assert message =~ "Aktualisiere deine Karte"
    assert message =~ "Payment didn't go through"
    assert message =~ "Update your card in billing"
    refute message =~ "Sie "
  end
end
