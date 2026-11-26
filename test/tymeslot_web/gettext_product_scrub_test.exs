defmodule TymeslotWeb.GettextProductScrubTest do
  use ExUnit.Case, async: false

  @moduletag :i18n

  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Brands

  test "the default test brand keeps the upstream name the suite asserts" do
    Brands.bind(nil)

    assert dgettext("onboarding", "Welcome to your Tymeslot dashboard") ==
             "Welcome to your Tymeslot dashboard"
  end

  test "a bound tenant name replaces the upstream product name" do
    brand = Brands.neutral_default()
    Brands.bind(%{brand | name: "Acme", house_brand: true, product_name: nil})

    assert dgettext("onboarding", "Welcome to your Tymeslot dashboard") ==
             "Welcome to your Acme dashboard"
  end
end
