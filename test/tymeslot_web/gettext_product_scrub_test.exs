defmodule TymeslotWeb.GettextProductScrubTest do
  use ExUnit.Case, async: false

  @moduletag :i18n

  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Brands

  test "the house brand shows BookDesk24 instead of the old product name" do
    Brands.bind(nil)

    assert dgettext("onboarding", "Welcome to your Tymeslot dashboard") ==
             "Welcome to your BookDesk24 dashboard"
  end

  test "a tenant name replaces the old product name" do
    brand = Brands.neutral_default()
    Brands.bind(%{brand | name: "Acme", house_brand: false, product_name: nil})

    assert dgettext("onboarding", "Welcome to your Tymeslot dashboard") ==
             "Welcome to your Acme dashboard"
  end
end
