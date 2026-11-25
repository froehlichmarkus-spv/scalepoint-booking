defmodule TymeslotWeb.Themes.Folio.Scheduling.Components.MastheadMoment do
  @moduledoc """
  The top of Folio's page, a moment collecting nothing, so it is there from
  the start: the full masthead (cover, portrait, name, headline and bio)
  and the summary bar of what the visitor has chosen
  (`Blocks.SummaryBar`, nothing until a meeting type is), whose links jump
  back to the moment that collected each choice.

  The bar carries the organiser: Folio wraps the shared bar with a small
  portrait and the name (`folio-summary-bar`), so the person stays on
  screen once the masthead scrolls away. Before a type is chosen and under
  a long bio (over 300 graphemes), a link between the name and headline
  and the bio goes down to the ways to work (`#offer-step`), which that bio
  would otherwise push below the first phone screen.

  The moment's root is laid out with `display: contents` (`page.css`), so
  the bar's sticky box is the journey's whole frame and it follows the
  visitor down the page.
  """
  use TymeslotWeb, :live_component

  alias Tymeslot.Brands
  alias Tymeslot.Demo
  alias Tymeslot.MeetingTypes
  alias Tymeslot.Profiles
  alias TymeslotWeb.Themes.Folio.Components.Masthead
  alias TymeslotWeb.Themes.Shared.BookingText
  alias TymeslotWeb.Themes.Shared.Blocks.SummaryBar
  alias TymeslotWeb.Themes.Shared.BookingLabels
  alias TymeslotWeb.Themes.Shared.BookingText
  alias TymeslotWeb.Themes.Shared.StepEvents

  @long_bio_graphemes 300

  @impl Phoenix.LiveComponent
  defdelegate update(assigns, socket), to: StepEvents

  @impl Phoenix.LiveComponent
  defdelegate handle_event(event, params, socket), to: StepEvents

  @impl Phoenix.LiveComponent
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :jump?,
        assigns.meeting_types != [] and is_nil(assigns.meeting_type) and
          long_bio?(assigns.organizer_profile)
      )
      |> assign(:host_facts, host_facts(assigns))

    ~H"""
    <section
      id={"#{@moment}-step"}
      class="folio-masthead-moment"
      data-moment={@moment}
      data-moment-state={@moment_state}
      data-locale={@locale}
    >
      <Masthead.masthead
        variant={:full}
        theme_tokens={@theme_tokens}
        organizer_profile={@organizer_profile}
        username_context={@username_context}
      >
        <:after_intro>
          <TymeslotWeb.Brands.SalesRoom.panel profile={@organizer_profile} locale={@locale} />
          <div :if={@host_facts} class="room room--host">
            <p :if={@host_facts.role} class="room__role">{@host_facts.role}</p>
            <p :if={@host_facts.company} class="room__company">{@host_facts.company}</p>
            <ul :if={@host_facts.duration || @host_facts.place} class="room__facts">
              <li :if={@host_facts.duration}>
                <.icon name="hero-clock" class="room__fact-icon" />
                <span>{@host_facts.duration}</span>
              </li>
              <li :if={@host_facts.place}>
                <.icon name="hero-map-pin" class="room__fact-icon" />
                <span>{@host_facts.place}</span>
              </li>
            </ul>
            <p :if={@host_facts.bio} class="room__bio">{@host_facts.bio}</p>
          </div>
        </:after_intro>
        <:after_intro :if={@jump?}>
          <a href="#offer-step" class="folio-jump" data-testid="folio-jump-to-offer">
            {BookingText.heading(
              @organizer_profile,
              :folio,
              Profiles.display_name(@organizer_profile)
            )}
            <.icon name="hero-arrow-down-mini" class="folio-jump__icon" />
          </a>
        </:after_intro>
      </Masthead.masthead>
      <div :if={@meeting_type} class="folio-summary-bar" data-testid="folio-summary-bar">
        <span :if={@organizer_profile} class="folio-summary-bar__person">
          <img
            class="folio-summary-bar__portrait"
            src={Demo.avatar_url(@organizer_profile, :thumb)}
            alt=""
          />
          <span class="folio-summary-bar__name">
            {BookingLabels.organizer_display_name(@organizer_profile, @username_context)}
          </span>
        </span>
        <SummaryBar.summary_bar
          journey={@journey}
          meeting_type={@meeting_type}
          selected_date={@selected_date}
          selected_time={@selected_time}
          user_timezone={@user_timezone}
        />
      </div>
    </section>
    """
  end

  # A bio of a few sentences leaves the ways to work in view; one of a few
  # paragraphs pushes them below the first phone screen.
  defp long_bio?(profile) when is_map(profile) do
    case Map.get(profile, :bio) do
      bio when is_binary(bio) -> String.length(String.trim(bio)) > @long_bio_graphemes
      _absent -> false
    end
  end

  defp long_bio?(_no_profile), do: false

  # A tenant document already fills this column. Everyone else gets the
  # host's own role, company, length, place and a short line, so the
  # portrait is not standing over an empty field.
  defp host_facts(%{organizer_profile: profile} = assigns) when is_map(profile) do
    if Brands.for_profile(profile) do
      nil
    else
      %{
        role: present(Map.get(profile, :headline)),
        company: present(Map.get(profile, :booking_greeting)),
        bio: present(Map.get(profile, :booking_instruction)) || present(Map.get(profile, :bio)),
        duration: duration_fact(assigns.meeting_type),
        place: place_fact(assigns.meeting_type)
      }
    end
  end

  defp host_facts(_assigns), do: nil

  defp duration_fact(nil), do: nil

  defp duration_fact(meeting_type) do
    BookingText.duration_label(%{meeting_type: meeting_type})
  end

  defp place_fact(nil), do: nil

  defp place_fact(meeting_type) do
    meeting_type
    |> MeetingTypes.location_options()
    |> List.first()
    |> case do
      %{label: label} -> present(label)
      _other -> nil
    end
  end

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      text -> text
    end
  end

  defp present(_value), do: nil
end
