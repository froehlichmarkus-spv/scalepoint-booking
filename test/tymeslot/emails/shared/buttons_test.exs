defmodule Tymeslot.Emails.Shared.ButtonsTest do
  use Tymeslot.DataCase, async: true
  @moduletag :emails

  alias Tymeslot.Emails.Shared.Buttons
  alias Tymeslot.Utils.Colour

  describe "action_button/4" do
    test "includes the URL and label in output for a valid https URL" do
      html = Buttons.action_button(:confirmed, "Book Now", "https://example.com/book")

      assert html =~ "https://example.com/book"
      assert html =~ "Book Now"
    end

    test "renders nothing for an unsafe or missing URL" do
      assert Buttons.action_button(:confirmed, "Click", "javascript:alert(1)") == ""
      assert Buttons.action_button(:confirmed, "Click", nil) == ""
    end

    test "passes mailto: URL through unchanged" do
      html = Buttons.action_button(:confirmed, "Email Us", "mailto:support@example.com")

      assert html =~ "mailto:support@example.com"
    end

    test "full_width: true produces a different output than the default" do
      html_full = Buttons.action_button(:confirmed, "Go", "https://example.com", full_width: true)
      html_default = Buttons.action_button(:confirmed, "Go", "https://example.com")

      refute html_full == html_default
      assert html_full =~ "mobile-button"
      refute html_default =~ "mobile-button"
    end

    test "renders the suite navy button for every intent" do
      for intent <- [:confirmed, :alert, :cancelled] do
        html = Buttons.action_button(intent, "Go", "https://example.com")

        assert html =~ ~s(background-color="#111E32")
        assert html =~ ~s(color="#FFFFFF")
      end
    end

    test "the suite navy button clears 4.5:1 against white text" do
      html = Buttons.action_button(:confirmed, "Go", "https://example.com")

      assert html =~ ~s(background-color="#111E32")
      assert html =~ ~s(color="#FFFFFF")
      assert Colour.contrast_ratio("#FFFFFF", "#111E32") >= 4.5
    end
  end
end
