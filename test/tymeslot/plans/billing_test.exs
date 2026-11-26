defmodule Tymeslot.Plans.BillingTest do
  use ExUnit.Case, async: true

  @moduledoc """
  The dashboard talks to growth-os-billing through one module. When that
  service cannot be reached, the sentence is informal German.
  """

  @moduletag :plans
  @moduletag :unit

  alias Tymeslot.Plans.Billing

  test "an unreachable billing service gets a branded informal German sentence" do
    message = Billing.unavailable_message()

    assert message =~ "BookDesk24"
    assert message =~ TymeslotWeb.ErrorHTML.support_email()
    assert message =~ "Versuch es später noch einmal"
    refute message =~ "Billing is unavailable"
    refute message =~ "Sie "
  end
end
