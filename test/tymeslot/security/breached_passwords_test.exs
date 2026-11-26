defmodule Tymeslot.Security.BreachedPasswordsTest do
  use ExUnit.Case, async: true

  @moduletag :security

  alias Tymeslot.Security.BreachedPasswords

  test "the local list matches regardless of case and ignores unknown passwords" do
    assert BreachedPasswords.local?("password")
    assert BreachedPasswords.local?("Password")
    refute BreachedPasswords.local?("bookdesk-local-ok")
  end

  test "a HIBP range body matches the suffix only when the count is positive" do
    suffix = "1E4C9B93F3F0682250B6CF8331B7EE68FD8"

    body = """
    0018A45C4D1DEF81644B54AB7F969B88D65:0
    #{suffix}:42
    FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF:1
    """

    assert BreachedPasswords.range_lists?(body, suffix)
    assert BreachedPasswords.range_lists?(body, String.downcase(suffix))
    refute BreachedPasswords.range_lists?(body, "0018A45C4D1DEF81644B54AB7F969B88D65")
  end
end
