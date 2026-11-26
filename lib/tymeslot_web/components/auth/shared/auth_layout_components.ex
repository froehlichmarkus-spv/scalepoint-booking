defmodule TymeslotWeb.Shared.Auth.LayoutComponents do
  @moduledoc """
  Layout and container components for authentication pages.
  """

  use TymeslotWeb, :html
  use Gettext, backend: TymeslotWeb.Gettext

  # `video: false` is for a page served by a plain controller, where no hook
  # mounts: the video would download and never play, and the motion toggle
  # would do nothing. It gets the static fallback gradient instead.
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :video, :boolean, default: false
  attr :preview, :string, default: nil
  attr :lock_seconds, :integer, default: 900
  slot :heading
  slot :form
  slot :social
  slot :footer

  @spec auth_card_layout(map()) :: Phoenix.LiveView.Rendered.t()
  def auth_card_layout(assigns) do
    ~H"""
    <div class="gos-auth" data-m="booking" id="main" data-video={to_string(@video)}>
      <aside class="gos-auth-art" aria-hidden="true">
        <p class="mod-chip">
          <.icon name="hero-calendar-days" class="gos-icon" /> BookDesk24
        </p>
        <div class="claim">
          <h2>{dgettext("auth", "Booking pages that look like your work.")}</h2>
          <p>
            {dgettext(
              "auth",
              "Nordlicht Analytics books an intro, a workshop and a follow-up from one page."
            )}
          </p>
          <ul class="proof">
            <li>
              <.icon name="hero-check" class="gos-icon" />
              {dgettext("auth", "14-day trial, no card")}
            </li>
            <li>
              <.icon name="hero-calendar-days" class="gos-icon" />
              {dgettext("auth", "Your calendar stays the source")}
            </li>
            <li>
              <.icon name="hero-envelope" class="gos-icon" />
              {dgettext("auth", "Guests get the confirmation by email")}
            </li>
          </ul>
        </div>
      </aside>
      <div class="gos-auth-main">
        <div class="gos-auth-top">
          {if @footer != [], do: render_slot(@footer)}
        </div>
        <div class="gos-auth-form">
          <div class="head">
            <h1>{@title}</h1>
            <p :if={@subtitle} class="sub">{@subtitle}</p>
          </div>
          {if @heading != [], do: render_slot(@heading)}
          <%= cond do %>
            <% @preview == "skeleton" -> %>
              <div class="gos-auth-status" role="status" aria-busy="true">
                <span class="sr-only">{dgettext("common", "Loading")}</span>
                <span class="skeleton skeleton-row__title"></span>
                <span class="skeleton skeleton-row__line"></span>
                <span class="skeleton skeleton-row__line"></span>
              </div>
            <% @preview == "empty" -> %>
              <div class="gos-auth-status" role="status">
                <h2>{dgettext("auth", "No sign-in method is switched on")}</h2>
                <p class="sub">
                  {dgettext("auth", "Ask an admin to turn on email or a provider.")}
                </p>
              </div>
            <% @preview == "permission" -> %>
              <div class="gos-auth-status" role="alert">
                <h2>{dgettext("auth", "You don't have access to BookDesk24")}</h2>
                <p class="sub">
                  {dgettext("auth", "Ask an admin if you need a seat on this workspace.")}
                </p>
              </div>
            <% @preview == "locked" -> %>
              <div
                class="gos-auth-status"
                role="alert"
                id="auth-lockout"
                phx-hook="GosLock"
                data-seconds={@lock_seconds}
              >
                <h2>{dgettext("auth", "Too many attempts")}</h2>
                <p class="sub">
                  {dgettext("auth", "Try again in")}
                  <span data-lock-clock>15:00</span>
                  {dgettext("auth", "or reset your password.")}
                </p>
                <button
                  type="button"
                  class="gos-btn gos-btn--secondary"
                  phx-click="navigate_to"
                  phx-value-to="reset_password"
                >
                  {dgettext("auth", "Forgot password?")}
                </button>
              </div>
            <% true -> %>
              <div class="space-y-6">
                {render_slot(@form)}
                <%= if @social != [] do %>
                  {render_slot(@social)}
                <% end %>
              </div>
          <% end %>
        </div>
        <div class="gos-auth-foot">
          <a href={Application.get_env(:tymeslot, :legal_terms_url) || "/growthos/legal/terms"}>
            {dgettext("auth", "Terms")}
          </a>
          <a href={Application.get_env(:tymeslot, :legal_privacy_url) || "/growthos/legal/privacy"}>
            {dgettext("auth", "Privacy")}
          </a>
        </div>
      </div>
    </div>
    """
  end

  @spec auth_footer(map()) :: Phoenix.LiveView.Rendered.t()
  def auth_footer(assigns) do
    assigns =
      assigns
      |> assign_new(:"phx-click", fn -> nil end)
      |> assign_new(:href, fn -> nil end)
      |> assign_new(:"phx-value-to", fn -> nil end)

    ~H"""
    <div class="text-center">
      <span class="text-sm text-tymeslot-500 font-bold">{@prompt}</span>
      <%= if assigns[:"phx-click"] do %>
        <button
          type="button"
          phx-click={assigns[:"phx-click"]}
          phx-value-to={assigns[:"phx-value-to"]}
          class="font-bold text-turquoise-600 hover:text-turquoise-700 transition-colors ml-2 bg-turquoise-50 hover:bg-turquoise-100 px-4 py-2 rounded-xl text-sm inline-block border-none cursor-pointer"
        >
          {@link_text}
        </button>
      <% else %>
        <a
          href={@href}
          class="font-bold text-turquoise-600 hover:text-turquoise-700 transition-colors ml-2 bg-turquoise-50 hover:bg-turquoise-100 px-4 py-2 rounded-xl text-sm inline-block"
        >
          {@link_text}
        </a>
      <% end %>
    </div>
    """
  end
end
