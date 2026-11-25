# Empty workspace for state shots. Idempotent.
# Ida Holm has no meetings and no meeting types.
# Noa Feld has one type and no open hours, so the month says there are no free times.
# Run: mix run priv/repo/leer_demo.exs

alias Tymeslot.Repo
alias Tymeslot.Availability.AvailabilityScheduleSchema
alias Tymeslot.Availability.WeeklyAvailabilitySchema
alias Tymeslot.Integrations.Calendar.CalendarIntegrationSchema
alias Tymeslot.MeetingTypes.MeetingTypeSchema
alias Tymeslot.Plans.Entitlement
alias Tymeslot.Profiles.ProfileSchema
import Ecto.Query

defmodule LeerDemo do
  def ensure(email, name, username, password) do
    user =
      case Tymeslot.Repo.get_by(Tymeslot.Auth.UserSchema, email: email) do
        nil ->
          %Tymeslot.Auth.UserSchema{}
          |> Tymeslot.Auth.UserSchema.registration_changeset(%{
            "email" => email,
            "password" => password,
            "password_confirmation" => password,
            "name" => name
          })
          |> Ecto.Changeset.put_change(:verified_at, DateTime.utc_now(:second))
          |> Ecto.Changeset.put_change(:locale, "de")
          |> Tymeslot.Repo.insert!()

        existing ->
          existing
      end

    now = DateTime.utc_now(:second)

    user =
      user
      |> Ecto.Changeset.change(%{
        locale: "de",
        onboarding_completed_at: user.onboarding_completed_at || now,
        dashboard_tour_seen_at: user.dashboard_tour_seen_at || now
      })
      |> Tymeslot.Repo.update!()

    profile =
      case Tymeslot.Repo.get_by(Tymeslot.Profiles.ProfileSchema, user_id: user.id) do
        nil ->
          %Tymeslot.Profiles.ProfileSchema{}
          |> Tymeslot.Profiles.ProfileSchema.create_changeset(%{
            user_id: user.id,
            full_name: name
          })
          |> Tymeslot.Repo.insert!()

        existing ->
          existing
      end

    profile =
      profile
      |> Tymeslot.Profiles.ProfileSchema.basic_changeset(%{
        full_name: name,
        timezone: "Europe/Berlin"
      })
      |> Tymeslot.Profiles.ProfileSchema.username_changeset(%{username: username})
      |> Tymeslot.Profiles.ProfileSchema.intro_changeset(%{
        headline: "Studio",
        bio: "Dieser Arbeitsbereich ist absichtlich leer."
      })
      |> Tymeslot.Profiles.ProfileSchema.booking_text_changeset(%{
        booking_text_enabled: true,
        booking_heading: "Zeit mit #{name}",
        booking_greeting: "Leerer Arbeitsbereich",
        booking_instruction: "Hier gibt es gerade keine freien Zeiten."
      })
      |> Tymeslot.Profiles.ProfileSchema.theme_changeset(%{
        booking_theme: "4",
        has_custom_theme: false
      })
      |> Ecto.Changeset.put_change(:booking_page_published_at, DateTime.utc_now(:second))
      |> Tymeslot.Repo.update!()

    {user, profile}
  end
end

{ida, _ida_profile} =
  LeerDemo.ensure("ida@leer-mail.io", "Ida Holm", "leer", "leer-harbor")

{noa, noa_profile} =
  LeerDemo.ensure("noa@leer-mail.io", "Noa Feld", "ohne-zeiten", "feld-harbor")

period_end = DateTime.utc_now(:second) |> DateTime.add(30, :day)

for user <- [ida, noa] do
  %Entitlement{}
  |> Entitlement.changeset(%{
    user_id: user.id,
    plan: "pro",
    status: "active",
    interval: "month",
    current_period_end: period_end,
    cancel_at_period_end: false,
    source_version: 1,
    show_badge_on_pro: false
  })
  |> Repo.insert(
    on_conflict: {:replace, [:plan, :status, :interval, :current_period_end, :show_badge_on_pro]},
    conflict_target: :user_id
  )
end

unless Repo.get_by(MeetingTypeSchema, user_id: noa.id, slug: "gespraech") do
  %MeetingTypeSchema{}
  |> MeetingTypeSchema.changeset(%{
    user_id: noa.id,
    name: "Gespräch",
    slug: "gespraech",
    duration_minutes: 30,
    description: "Ein Gespräch, für das gerade kein Fenster offen ist.",
    sort_order: 0,
    is_active: true,
    icon: "hero-clock",
    locations: [%{kind: "in_person", label: "Berlin", position: 0}]
  })
  |> Repo.insert!()
end

schedule =
  case Repo.get_by(AvailabilityScheduleSchema, profile_id: noa_profile.id, is_default: true) do
    nil ->
      %AvailabilityScheduleSchema{}
      |> AvailabilityScheduleSchema.changeset(%{
        profile_id: noa_profile.id,
        name: "Geschlossen",
        is_default: true,
        buffer_before_minutes: 0,
        buffer_after_minutes: 0,
        min_advance_hours: 0,
        advance_booking_days: 3
      })
      |> Repo.insert!()

    existing ->
      existing
      |> AvailabilityScheduleSchema.changeset(%{advance_booking_days: 3})
      |> Repo.update!()
  end

if Repo.aggregate(
     from(d in WeeklyAvailabilitySchema, where: d.schedule_id == ^schedule.id),
     :count
   ) ==
     0 do
  for day <- 1..7 do
    %WeeklyAvailabilitySchema{}
    |> WeeklyAvailabilitySchema.changeset(%{
      schedule_id: schedule.id,
      day_of_week: day,
      is_available: false,
      start_time: ~T[09:00:00],
      end_time: ~T[17:00:00]
    })
    |> Repo.insert!()
  end
end

unless Repo.get_by(CalendarIntegrationSchema, user_id: noa.id, name: "Leer Kalender") do
  %CalendarIntegrationSchema{}
  |> CalendarIntegrationSchema.changeset(%{
    user_id: noa.id,
    name: "Leer Kalender",
    provider: "caldav",
    base_url: "https://cal.leer-mail.io",
    username: "noa",
    password: "demo-calendar",
    provider_account_id: "leer-noa",
    provider_account_email: "noa@leer-mail.io",
    is_active: true,
    verify_ssl: true
  })
  |> Repo.insert!()
end

IO.puts("Leer ready: /leer (Ida, empty) and /ohne-zeiten/gespraech (Noa, no open hours)")
