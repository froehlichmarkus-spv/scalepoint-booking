defmodule Tymeslot.Integrations.Calendar.DemoCalendarProvider do
  @moduledoc """
  Demo calendar provider that generates sample calendar events for public demos.

  This provider:
  - Shows realistic availability patterns
  - Never marks demo bookings as busy
  - Provides consistent demo experience
  """

  @behaviour Tymeslot.Integrations.Calendar.Provider

  # Reuse most functionality from debug provider
  alias Tymeslot.Integrations.Calendar.CreatedEvent
  alias Tymeslot.Integrations.Calendar.DebugCalendarProvider

  @impl Tymeslot.Integrations.Calendar.Provider
  defdelegate new(config), to: DebugCalendarProvider

  @impl Tymeslot.Integrations.Calendar.Provider
  def create_event(_client, _event_data) do
    # Demo mode: pretend to create the event but don't actually do anything
    {:ok, CreatedEvent.provider_minted("demo-event-#{:rand.uniform(999_999)}")}
  end

  @impl Tymeslot.Integrations.Calendar.Provider
  def update_event(_client, _uid, _event_data) do
    # Demo mode: pretend to update successfully
    :ok
  end

  @impl Tymeslot.Integrations.Calendar.Provider
  def delete_event(_client, _uid, _opts) do
    # Demo mode: pretend to delete successfully
    :ok
  end

  @impl Tymeslot.Integrations.Calendar.Provider
  def provider_type, do: :demo

  @impl Tymeslot.Integrations.Calendar.Provider
  def display_name, do: "Demo Calendar"

  @impl Tymeslot.Integrations.Calendar.Provider
  def connection_test_bucket, do: :unmetered

  @impl Tymeslot.Integrations.Calendar.Provider
  defdelegate config_schema, to: DebugCalendarProvider

  @impl Tymeslot.Integrations.Calendar.Provider
  defdelegate validate_config(config), to: DebugCalendarProvider

  # The debug provider only builds a client in :dev/:test. A production-mode
  # local demo still needs one, and only while the operator turned the
  # provider on. Busy times stay empty, so the weekly hours are bookable.
  @impl Tymeslot.Integrations.Calendar.Provider
  def build_client_configs(integration) do
    if enabled?(), do: [%{user_id: integration.user_id}], else: []
  end

  @impl Tymeslot.Integrations.Calendar.Provider
  def build_booking_client_config(integration) do
    if enabled?(), do: %{user_id: integration.user_id}, else: nil
  end

  defp enabled? do
    case Application.get_env(:tymeslot, :calendar_providers, %{})[:demo] do
      options when is_list(options) -> Keyword.get(options, :enabled, false)
      %{enabled: value} -> value
      _unused -> false
    end
  end

  # No fake busy blocks. The host's weekly hours are the availability a
  # visitor sees, which is what a local demo without Google needs.
  @impl Tymeslot.Integrations.Calendar.Provider
  def list_events(_client, _opts), do: {:ok, []}

  @impl Tymeslot.Integrations.Calendar.Provider
  def list_events_representation, do: :raw

  @impl Tymeslot.Integrations.Calendar.Provider
  def convert_events(events), do: events

  @impl Tymeslot.Integrations.Calendar.Provider
  def normalise_events(_raw_events, _context), do: {:ok, []}

  @impl Tymeslot.Integrations.Calendar.Provider
  def check_connectivity(_client), do: {:ok, %{status: :skipped, reason: "Demo provider"}}

  @doc """
  Tests the connection for the demo calendar provider.
  Always returns success.
  """
  @impl Tymeslot.Integrations.Calendar.Provider
  @spec perform_connection_test(term()) :: {:ok, String.t()}
  def perform_connection_test(_integration) do
    {:ok, "Demo calendar connection successful"}
  end
end
