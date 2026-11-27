defmodule Tymeslot.Emails.Shared.MailCards do
  @moduledoc """
  Product cards from Growth OS mail base v3.

  Booking mails use the slot card. Billing notices use the invoice card.
  Values are escaped. The HTML uses the same classes as `card-slot.html`
  and `card-invoice.html` so the base dark-mode rules apply.
  """

  alias Tymeslot.Emails.Shared.{Formatting, Sanitise}

  @font "Geist,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"
  @tones %{
    success: {"chip-success", "#E1F5EA", "#0F6B47"},
    warning: {"chip-warning", "#FFF3D6", "#835000"},
    danger: {"chip-danger", "#FDECEA", "#B42318"},
    neutral: {"chip-neutral", "#EEF2F7", "#3C4656"},
    module: {"chip-module", "#FFF3D6", "#835000"}
  }

  @doc "Slot card for a confirmation, reminder, reschedule or cancellation."
  @spec slot(map()) :: %{html: String.t(), text: String.t()}
  def slot(spec) when is_map(spec) do
    rows = spec[:rows] || []

    html = """
    <table role="presentation" class="pc" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#F8FAFD" style="background:#F8FAFD;border:1px solid #DCE3EC;border-radius:12px;border-collapse:separate"><tr><td class="pcp" style="padding:16px 18px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>#{date_cell(spec)}<td valign="middle" style="padding-left:14px;font-family:#{@font};font-size:13px;line-height:19px;font-weight:400;color:#4A5566" class="mu"><b class="tx" style="display:block;font-family:#{@font};font-size:16px;line-height:22px;font-weight:600;color:#111E32">#{esc(spec[:title])}</b>#{esc(spec[:sub])}</td>#{chip(spec[:status], spec[:tone] || :success)}</tr></table></td></tr>#{divider()}#{rows_html(rows)}</table>
    """

    text =
      [
        "#{spec[:day]} #{spec[:mon]} · #{spec[:title]} — #{spec[:status]}",
        spec[:sub]
        | Enum.map(rows, fn {k, v} -> "- #{k}: #{v}" end)
      ]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("\n")

    %{html: html, text: text}
  end

  @doc "Invoice card for a trial, plan or payment notice."
  @spec invoice(map()) :: %{html: String.t(), text: String.t()}
  def invoice(spec) when is_map(spec) do
    html = """
    <table role="presentation" class="pc" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#F8FAFD" style="background:#F8FAFD;border:1px solid #DCE3EC;border-radius:12px;border-collapse:separate"><tr><td class="pcp" style="padding:16px 18px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td valign="middle" class="mu" style="font-family:#{@font};font-size:13px;line-height:19px;color:#4A5566"><b class="tx" style="display:block;font-family:#{@font};font-size:16px;line-height:22px;font-weight:600;color:#111E32">#{esc(spec[:plan])}</b>#{esc(spec[:invoice_no])}</td>#{chip(spec[:status], spec[:tone] || :neutral)}</tr></table></td></tr>#{divider()}<tr><td class="pcr" style="padding:12px 18px 4px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td class="mu" style="font-family:#{@font};font-size:14px;line-height:21px;color:#4A5566;padding-right:12px">#{esc(spec[:line])}</td><td class="tx" align="right" style="font-family:#{@font};font-size:14px;line-height:21px;font-weight:500;color:#111E32">#{esc(spec[:amount])}</td></tr></table></td></tr><tr><td class="pcr" style="padding:8px 18px 14px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td class="ln" height="1" bgcolor="#DCE3EC" style="height:1px;background:#DCE3EC">&nbsp;</td></tr><tr><td class="tx" style="padding-top:10px;font-family:#{@font};font-size:15px;line-height:22px;font-weight:600;color:#111E32">#{esc(spec[:total_label])}</td><td class="tx" align="right" style="padding-top:10px;font-family:#{@font};font-size:15px;line-height:22px;font-weight:700;color:#111E32">#{esc(spec[:total])}</td></tr></table></td></tr>#{note(spec[:note])}</table>
    """

    text =
      """
      #{spec[:plan]} — #{spec[:status]}
      #{spec[:invoice_no]}
      - #{spec[:line]}: #{spec[:amount]}
      #{spec[:total_label]}: #{spec[:total]}
      #{spec[:note]}
      """

    %{html: html, text: String.trim(text)}
  end

  @doc "A slot spec from an appointment payload."
  @spec slot_spec(map(), String.t(), String.t(), atom(), :attendee | :owner) :: map()
  def slot_spec(details, locale, status, tone, clock \\ :attendee) do
    date = slot_date(details, clock)

    %{
      mon: month_abbr(date, locale),
      day: if(date, do: Integer.to_string(date.day), else: ""),
      title: Map.get(details, :meeting_type) || Map.get(details, :title) || "Booking",
      sub: time_line(details, locale, clock),
      status: status,
      tone: tone,
      rows: slot_rows(details, locale)
    }
  end

  defp date_cell(spec) do
    ~s(<td width="52" valign="middle" style="width:52px"><table role="presentation" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate"><tr><td class="av" width="52" align="center" bgcolor="#FFF3D6" style="background:#FFF3D6;border-radius:10px;padding:6px 0 7px;color:#835000;font-family:#{@font};font-size:11px;line-height:14px;font-weight:700;letter-spacing:.08em;text-transform:uppercase">#{esc(spec[:mon])}<br><span style="font-family:#{@font};font-size:20px;line-height:24px;font-weight:700">#{esc(spec[:day])}</span></td></tr></table></td>)
  end

  defp chip(nil, _tone), do: ""

  defp chip(label, tone) do
    {class, bg, fg} = Map.get(@tones, tone, @tones.neutral)

    ~s(<td align="right" valign="middle" style="padding-left:10px"><table role="presentation" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;display:inline-table"><tr><td class="#{class}" bgcolor="#{bg}" style="background:#{bg};color:#{fg};border-radius:999px;padding:4px 10px;font-family:#{@font};font-size:12px;line-height:16px;font-weight:600;white-space:nowrap">&#9679;&nbsp;#{esc(label)}</td></tr></table></td>)
  end

  defp divider do
    ~s(<tr><td class="pcr" style="padding:0 18px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td class="ln" height="1" bgcolor="#DCE3EC" style="height:1px;line-height:1px;font-size:1px;background:#DCE3EC">&nbsp;</td></tr></table></td></tr>)
  end

  defp rows_html([]), do: ""

  defp rows_html(rows) do
    rows
    |> Enum.with_index()
    |> Enum.map_join("", fn {{k, v}, i} ->
      top = if i == 0, do: 12, else: 4

      ~s(<tr><td class="pcr" style="padding:#{top}px 18px 4px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td class="mu" valign="top" style="font-family:#{@font};font-size:14px;line-height:21px;color:#4A5566;padding-right:12px">#{esc(k)}</td><td class="tx" align="right" valign="top" style="font-family:#{@font};font-size:14px;line-height:21px;font-weight:500;color:#111E32">#{esc(v)}</td></tr></table></td></tr>)
    end)
  end

  defp note(nil), do: ""
  defp note(""), do: ""

  defp note(text) do
    ~s(<tr><td class="pcr mu" style="padding:0 18px 14px;font-family:#{@font};font-size:13px;line-height:19px;color:#4A5566">#{esc(text)}</td></tr>)
  end

  defp slot_date(details, clock) do
    case slot_instant(details, clock) do
      %DateTime{} = dt -> DateTime.to_date(dt)
      %Date{} = date -> date
      _other -> nil
    end
  end

  defp slot_instant(details, :owner) do
    Map.get(details, :start_time_owner_tz) || Map.get(details, :start_time_attendee_tz) ||
      Map.get(details, :date)
  end

  defp slot_instant(details, _attendee) do
    Map.get(details, :start_time_attendee_tz) || Map.get(details, :start_time_owner_tz) ||
      Map.get(details, :date)
  end

  defp month_abbr(nil, _locale), do: ""

  defp month_abbr(%Date{} = date, "de") do
    Enum.at(~w(JAN FEB MÄR APR MAI JUN JUL AUG SEP OKT NOV DEZ), date.month - 1)
  end

  defp month_abbr(%Date{} = date, _locale) do
    date |> Calendar.strftime("%b") |> String.upcase()
  end

  defp time_line(details, locale, clock) do
    case slot_instant(details, clock) do
      %DateTime{} = start ->
        date = DateTime.to_date(start)

        clock_details = %{
          start_time: start,
          date: date,
          duration: Map.get(details, :duration),
          time_format: if(clock == :owner, do: Map.get(details, :organizer_time_format))
        }

        [
          Formatting.format_weekday(date, locale),
          Formatting.format_date(date, locale),
          Formatting.format_meeting_time(clock_details, locale)
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" · ")

      %Date{} = date ->
        Enum.join(
          [Formatting.format_weekday(date, locale), Formatting.format_date(date, locale)],
          " · "
        )

      _other ->
        nil
    end
  end

  defp slot_rows(details, locale) do
    duration =
      case Map.get(details, :duration) do
        minutes when is_integer(minutes) -> Formatting.format_duration(minutes, locale)
        _other -> nil
      end

    location = Map.get(details, :location)

    []
    |> maybe_row(with_label(locale), Map.get(details, :organizer_name))
    |> maybe_row(duration_label(locale), duration)
    |> maybe_row(location_label(locale), location)
  end

  defp maybe_row(rows, _label, value) when value in [nil, ""], do: rows
  defp maybe_row(rows, label, value), do: rows ++ [{label, value}]

  defp with_label("de"), do: "Mit"
  defp with_label(_locale), do: "With"
  defp location_label("de"), do: "Ort"
  defp location_label(_locale), do: "Location"
  defp duration_label("de"), do: "Dauer"
  defp duration_label(_locale), do: "Duration"

  defp esc(nil), do: ""
  defp esc(value), do: Sanitise.sanitize_for_email(to_string(value))
end
