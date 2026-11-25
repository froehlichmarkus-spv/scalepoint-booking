defmodule Tymeslot.SalesRooms.Metrics do
  @moduledoc """
  Counts sales-room page views and document downloads.

  A count is one number per booking page. Nothing about the visitor is stored.
  """

  alias Tymeslot.SalesRooms.SalesRoomQueries

  @doc "The counters for a profile page, or zeros when none have been recorded."
  @spec get(integer(), integer() | nil) :: %{
          page_views: non_neg_integer(),
          document_downloads: non_neg_integer()
        }
  def get(profile_id, booking_page_id) when is_integer(profile_id) do
    case SalesRoomQueries.counter(profile_id, booking_page_id) do
      nil -> %{page_views: 0, document_downloads: 0}
      counter -> %{page_views: counter.page_views, document_downloads: counter.document_downloads}
    end
  end

  @doc "Adds one page view. Safe to call more than once for the same page."
  @spec record_view(integer(), integer() | nil) :: :ok
  def record_view(profile_id, booking_page_id) when is_integer(profile_id) do
    SalesRoomQueries.bump_counter(profile_id, booking_page_id, :page_views)
  end

  @doc "Adds one document download."
  @spec record_download(integer(), integer() | nil) :: :ok
  def record_download(profile_id, booking_page_id) when is_integer(profile_id) do
    SalesRoomQueries.bump_counter(profile_id, booking_page_id, :document_downloads)
  end
end
