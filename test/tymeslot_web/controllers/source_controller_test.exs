defmodule TymeslotWeb.SourceControllerTest do
  @moduledoc """
  The AGPL license page and the booking footer both use the configured
  source URL. The public repository is that URL.
  """

  use TymeslotWeb.ConnCase, async: false

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  @moduletag :legal

  alias Tymeslot.Licensing.SourceOffer
  alias TymeslotWeb.Themes.Shared.Components.LegalLinks

  @url "https://github.com/froehlichmarkus-spv/scalepoint-booking"

  setup do
    previous = Application.get_env(:tymeslot, :source_offer_url)
    Application.put_env(:tymeslot, :source_offer_url, @url)

    on_exit(fn ->
      if is_binary(previous) do
        Application.put_env(:tymeslot, :source_offer_url, previous)
      else
        Application.delete_env(:tymeslot, :source_offer_url)
      end
    end)

    :ok
  end

  test "the license page links the public repository", %{conn: conn} do
    body = conn |> get(~p"/source") |> html_response(200)

    assert body =~ "Quellcode"
    assert body =~ "GNU AGPLv3"
    assert body =~ @url
    assert SourceOffer.default_url() == @url
  end

  test "the booking footer uses the same source URL" do
    assigns = %{links: nil}
    html = rendered_to_string(~H"<LegalLinks.footer links={@links} />")

    assert html =~ ~s(data-testid="source-offer")
    assert html =~ @url
    assert html =~ "Quellcode (AGPLv3)"
  end
end
