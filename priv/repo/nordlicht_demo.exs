# Demo workspace for product shots. Idempotent.
# Lena Hartmann, Nordlicht Analytics, BookDesk24 Pro.
# Run: mix run priv/repo/nordlicht_demo.exs

alias Tymeslot.Repo
alias Tymeslot.Auth.UserSchema
alias Tymeslot.Availability.{AvailabilityScheduleSchema, WeeklyAvailabilitySchema}
alias Tymeslot.Integrations.Calendar.CalendarIntegrationSchema
alias Tymeslot.Meetings.MeetingSchema
alias Tymeslot.MeetingTypes.MeetingTypeSchema
alias Tymeslot.Plans.Entitlement
alias Tymeslot.Profiles.ProfileSchema
import Ecto.Query

email = "lena@nordlicht-mail.io"
password = "nordlicht-harbor"

user =
  case Repo.get_by(UserSchema, email: email) do
    nil ->
      %UserSchema{}
      |> UserSchema.registration_changeset(%{
        "email" => email,
        "password" => password,
        "password_confirmation" => password,
        "name" => "Lena Hartmann"
      })
      |> Ecto.Changeset.put_change(:verified_at, DateTime.utc_now(:second))
      |> Ecto.Changeset.put_change(:locale, "de")
      |> Repo.insert!()

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
  |> Repo.update!()

profile =
  case Repo.get_by(ProfileSchema, user_id: user.id) do
    nil ->
      %ProfileSchema{}
      |> ProfileSchema.create_changeset(%{user_id: user.id, full_name: "Lena Hartmann"})
      |> Repo.insert!()

    existing ->
      existing
  end

profile =
  profile
  |> ProfileSchema.basic_changeset(%{full_name: "Lena Hartmann", timezone: "Europe/Berlin"})
  |> ProfileSchema.username_changeset(%{username: "nordlicht"})
  |> ProfileSchema.intro_changeset(%{
    headline: "Analytics lead, Nordlicht Analytics",
    bio:
      "Lena hilft Teams, aus verstreuten Zahlen eine klare nächste Entscheidung zu machen. Intro 30 Minuten, Workshop 60 Minuten. Europe/Berlin."
  })
  |> ProfileSchema.booking_text_changeset(%{
    booking_text_enabled: true,
    booking_heading: "Zeit mit Lena Hartmann",
    booking_greeting: "Nordlicht Analytics",
    booking_instruction:
      "Wähle einen Tag und eine Uhrzeit. Du bekommst die Bestätigung per E-Mail."
  })
  |> ProfileSchema.theme_changeset(%{booking_theme: "4", has_custom_theme: false})
  |> Ecto.Changeset.put_change(:booking_page_published_at, DateTime.utc_now(:second))
  |> Ecto.Changeset.put_change(:avatar, "lena.jpg")
  |> Repo.update!()

portrait = Path.expand("demo/lena-hartmann.jpg", __DIR__)

if File.exists?(portrait) do
  dest_dir =
    Path.join([
      Application.fetch_env!(:tymeslot, :upload_directory),
      "avatars",
      Integer.to_string(profile.id)
    ])

  File.mkdir_p!(dest_dir)
  File.cp!(portrait, Path.join(dest_dir, "lena.jpg"))
end

schedule =
  case Repo.one(
         from s in AvailabilityScheduleSchema,
           where: s.profile_id == ^profile.id and s.is_default == true
       ) do
    nil ->
      %AvailabilityScheduleSchema{}
      |> AvailabilityScheduleSchema.changeset(%{
        profile_id: profile.id,
        name: "Arbeitswoche",
        is_default: true,
        buffer_before_minutes: 0,
        buffer_after_minutes: 0,
        min_advance_hours: 0,
        advance_booking_days: 60
      })
      |> Repo.insert!()

    existing ->
      existing
  end

if Repo.aggregate(
     from(d in WeeklyAvailabilitySchema, where: d.schedule_id == ^schedule.id),
     :count
   ) == 0 do
  for day <- 1..5 do
    %WeeklyAvailabilitySchema{}
    |> WeeklyAvailabilitySchema.changeset(%{
      schedule_id: schedule.id,
      day_of_week: day,
      is_available: true,
      start_time: ~T[09:00:00],
      end_time: ~T[17:00:00]
    })
    |> Repo.insert!()
  end
end

unless Repo.get_by(CalendarIntegrationSchema, user_id: user.id, name: "Nordlicht Kalender") do
  %CalendarIntegrationSchema{}
  |> CalendarIntegrationSchema.changeset(%{
    user_id: user.id,
    name: "Nordlicht Kalender",
    provider: "caldav",
    base_url: "https://cal.nordlicht-mail.io",
    username: "lena",
    password: "demo-calendar",
    provider_account_id: "nordlicht-lena",
    provider_account_email: email,
    is_active: true,
    verify_ssl: true
  })
  |> Repo.insert!()
end

types = [
  %{
    name: "Intro",
    slug: "intro",
    duration_minutes: 30,
    description:
      "Ein erstes Gespräch: woran Nordlicht arbeitet und ob ein gemeinsames Projekt passt.",
    sort_order: 0
  },
  %{
    name: "Workshop",
    slug: "workshop",
    duration_minutes: 60,
    description: "Sechzig Minuten an einem konkreten Datensatz. Du bringst eine Frage mit.",
    sort_order: 1
  },
  %{
    name: "Folgegespräch",
    slug: "folge",
    duration_minutes: 45,
    description:
      "Für Teams, die schon mit Lena arbeiten. Status, offene Punkte, nächster Schritt.",
    sort_order: 2
  }
]

for attrs <- types do
  unless Repo.get_by(MeetingTypeSchema, user_id: user.id, slug: attrs.slug) do
    %MeetingTypeSchema{}
    |> MeetingTypeSchema.changeset(
      Map.merge(attrs, %{
        user_id: user.id,
        is_active: true,
        icon: "hero-bolt",
        locations: [
          %{kind: "in_person", label: "Nordlicht, Berlin", position: 0}
        ]
      })
    )
    |> Repo.insert!()
  end
end

period_end = DateTime.utc_now(:second) |> DateTime.add(30, :day)

_ =
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

guests = [
  {"Katrin Vogel", "katrin.vogel@example.com", 2},
  {"Mikael Lindqvist", "mikael.lindqvist@example.com", 26},
  {"Sara Okafor", "sara.okafor@example.com", 50}
]

now = DateTime.utc_now(:second)

for {name, guest_email, hours} <- guests do
  start_at = DateTime.add(now, hours, :hour) |> DateTime.truncate(:second)

  unless Repo.get_by(MeetingSchema, organizer_user_id: user.id, attendee_email: guest_email) do
    %MeetingSchema{}
    |> MeetingSchema.changeset(%{
      uid: Ecto.UUID.generate(),
      calendar_uid: Ecto.UUID.generate(),
      title: "Intro",
      summary: "Intro mit #{name}",
      description: "Nordlicht Analytics",
      start_time: start_at,
      end_time: DateTime.add(start_at, 30, :minute),
      duration: 30,
      location: "Nordlicht, Berlin",
      meeting_type: "Intro",
      organizer_name: "Lena Hartmann",
      organizer_email: email,
      organizer_user_id: user.id,
      attendee_name: name,
      attendee_email: guest_email,
      attendee_timezone: "Europe/Berlin",
      attendee_locale: "de",
      status: :confirmed,
      ical_sequence: 0
    })
    |> Repo.insert!()
  end
end

IO.puts("Nordlicht ready: http://localhost:4000/nordlicht  login #{email}")
