defmodule Tymeslot.BrandsCssTest do
  use ExUnit.Case, async: true

  test "a multi-word heading family is quoted so font-family keeps it" do
    css = Tymeslot.Brands.neutral_default() |> Tymeslot.Brands.css()

    assert css =~ ~s(--room-heading: "DM Serif Display";)
  end
end
