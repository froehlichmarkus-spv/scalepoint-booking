# Local demo for the Nordlicht Analytics sales room.
# Run: PLANS_ENABLED=true mix run priv/dev/seed_nordlicht.exs
# Password is a local demo password only.

defmodule NordlichtSeed do
  alias Tymeslot.Auth.UserQueries
  alias Tymeslot.Integrations.Calendar.CalendarIntegrationSchema
  alias Tymeslot.Auth.UserSchema
  alias Tymeslot.MeetingTypes.MeetingTypeSchema
  alias Tymeslot.Plans
  alias Tymeslot.Profiles
  alias Tymeslot.Profiles.ProfileSchema
  alias Tymeslot.Repo
  alias Tymeslot.SalesRooms
  alias Tymeslot.SalesRooms.Document
  alias Tymeslot.SalesRooms.Storage

  import Ecto.Query

  def run do
    email = "lena.hartmann@nordlichtanalytics.de"
    password = "Nordlicht-Demo-24"
    assets = "/tmp/nordlicht"

    now = DateTime.utc_now(:second)

    user =
      case Repo.get_by(UserSchema, email: email) do
        nil ->
          {:ok, created} =
            UserQueries.create_user(%{
              email: email,
              password: password,
              password_confirmation: password,
              name: "Lena Hartmann"
            })

          created

        existing ->
          existing
      end

    user =
      user
      |> Ecto.Changeset.change(%{
        verified_at: user.verified_at || now,
        onboarding_completed_at: user.onboarding_completed_at || now,
        locale: "de",
        name: "Lena Hartmann"
      })
      |> Repo.update!()

    profile =
      case Profiles.get_profile_by_user_id(user.id) do
        {:ok, existing} ->
          existing

        _missing ->
          {:ok, created} = Profiles.create_profile(user.id)
          created
      end

    {:ok, profile} =
      profile
      |> ProfileSchema.username_changeset(%{username: "nordlicht"})
      |> Repo.update()

    profile =
      profile
      |> Ecto.Changeset.change(%{
        full_name: "Lena Hartmann",
        booking_theme: "4",
        content_locale: "de",
        bio:
          "Nordlicht Analytics hilft Führungsteams, aus verstreuten Zahlen eine Entscheidung zu machen."
      })
      |> Repo.update!()

    Plans.upsert_entitlement(%{
      "data" => %{
        "external_user_id" => "booking:#{user.id}",
        "plan" => "pro",
        "status" => "active"
      },
      "version" => 3
    })

    Plans.invalidate(user.id)

    calendar =
      Repo.get_by(CalendarIntegrationSchema, user_id: user.id, provider: "debug") ||
        (
          {:ok, created} =
            %CalendarIntegrationSchema{}
            |> CalendarIntegrationSchema.changeset(%{
              name: "Nordlicht",
              provider: "debug",
              user_id: user.id,
              is_active: true,
              base_url: "https://calendar.nordlicht.test"
            })
            |> Repo.insert()

          created
        )

    Repo.update_all(
      from(mt in MeetingTypeSchema, where: mt.user_id == ^user.id),
      set: [
        name: "Strategiegespräch",
        description: "45 Minuten. Eine klare Empfehlung, kein Pitch.",
        duration_minutes: 45,
        calendar_integration_id: calendar.id
      ]
    )

    store = fn path, kind ->
      temp =
        Path.join(
          System.tmp_dir!(),
          "nordlicht-#{System.unique_integer([:positive])}#{Path.extname(path)}"
        )

      File.cp!(path, temp)

      case Storage.store(profile.id, kind, %{path: temp}) do
        {:ok, stored} -> stored
        {:ok, stored, _bytes} -> stored
        other -> raise "store failed: #{inspect(other)}"
      end
    end

    portrait = store.(Path.join(assets, "lena.jpg"), :image)
    workshop = store.(Path.join(assets, "workshop.jpg"), :image)
    harbor = store.(Path.join(assets, "harbor.jpg"), :image)
    cards = store.(Path.join(assets, "cards.jpg"), :image)
    mira = store.(Path.join(assets, "mira.jpg"), :image)
    jonas = store.(Path.join(assets, "jonas.jpg"), :image)
    helios = store.(Path.join(assets, "HELIOS.png"), :image)
    kueste = store.(Path.join(assets, "KUESTE.png"), :image)
    nordwerk = store.(Path.join(assets, "NORDWERK.png"), :image)
    aurum = store.(Path.join(assets, "AURUM.png"), :image)

    pdf = Path.join(assets, "ueberblick.pdf")
    temp_pdf = Path.join(System.tmp_dir!(), "nordlicht-brief.pdf")
    File.cp!(pdf, temp_pdf)
    {:ok, brochure, bytes} = Storage.store(profile.id, :document, %{path: temp_pdf})

    document =
      Document.blank()
      |> put("hero", %{
        "enabled" => true,
        "headline" => "Klarheit für Ihre Zahlen.",
        "subline" =>
          "Nordlicht Analytics führt Führungsteams in 45 Minuten von verstreuten Berichten zu einer Entscheidung.",
        "image_path" => portrait,
        "image_alt" => "Lena Hartmann im Hamburger Atelier von Nordlicht Analytics",
        "image_kind" => "portrait"
      })
      |> put("offer", %{
        "enabled" => true,
        "items" => [
          %{
            "title" => "Ein Bild, keine Folienflut",
            "text" => "Die Kennzahlen, die Ihre nächste Entscheidung tragen."
          },
          %{
            "title" => "Für den Vorstand verständlich",
            "text" => "Sprache, die Finance und Geschäftsführung teilen."
          },
          %{
            "title" => "In sechs Wochen wirksam",
            "text" => "Ein Rhythmus, den Ihr Team ohne Programm halten kann."
          },
          %{
            "title" => "Vertraulich von Anfang an",
            "text" => "Ihre Zahlen bleiben in Ihrem Haus."
          }
        ]
      })
      |> put("gallery", %{
        "enabled" => true,
        "images" => [
          %{"path" => workshop, "alt" => "Workshop mit dem Führungsteam an einem hellen Tisch"},
          %{
            "path" => harbor,
            "alt" => "Blick aus dem Atelier auf den Hafen, ein Chart auf dem Tisch"
          },
          %{
            "path" => cards,
            "alt" => "Karten mit einer ruhigen Auswertung auf dunkelblauem Leinen"
          }
        ]
      })
      |> put("video", %{
        "enabled" => true,
        "title" => "Zwei Minuten mit Lena",
        "url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      })
      |> put("documents", %{
        "enabled" => true,
        "files" => [%{"path" => brochure, "name" => "Nordlicht-Ueberblick.pdf", "bytes" => bytes}]
      })
      |> put("testimonials", %{
        "enabled" => true,
        "items" => [
          %{
            "quote" =>
              "Zum ersten Mal sah der Vorstand dieselbe Zahl. Die Diskussion wurde kürzer und besser.",
            "name" => "Mira Sen",
            "company" => "Küstenwerk",
            "photo_path" => mira,
            "photo_alt" => "Porträt von Mira Sen"
          },
          %{
            "quote" => "Kein Theater. Eine Empfehlung, die wir am Montag umsetzen konnten.",
            "name" => "Jonas Holm",
            "company" => "Nordwerk",
            "photo_path" => jonas,
            "photo_alt" => "Porträt von Jonas Holm"
          }
        ]
      })
      |> put("logos", %{
        "enabled" => true,
        "items" => [
          %{"path" => helios, "alt" => "Helios"},
          %{"path" => kueste, "alt" => "Küste"},
          %{"path" => nordwerk, "alt" => "Nordwerk"},
          %{"path" => aurum, "alt" => "Aurum"}
        ]
      })
      |> put("faq", %{
        "enabled" => true,
        "items" => [
          %{
            "question" => "Wie läuft das Gespräch ab?",
            "answer" =>
              "Wir klären die Entscheidung, die ansteht, und Sie gehen mit einer Empfehlung."
          },
          %{
            "question" => "Müssen wir Daten vorab schicken?",
            "answer" =>
              "Ein Export reicht. Wir arbeiten in Ihrem Rhythmus, nicht in einem Datenprojekt."
          }
        ]
      })
      |> put("cta", %{
        "enabled" => true,
        "headline" => "45 Minuten. Eine Empfehlung.",
        "text" =>
          "Wählen Sie einen Termin. Lena bereitet sich auf Ihre Frage vor, nicht auf eine Präsentation.",
        "button" => "Termin wählen"
      })

    {:ok, document} = document
    {:ok, _} = SalesRooms.save(profile, nil, nil, document)

    IO.puts("Nordlicht ready: http://localhost:4000/nordlicht?locale=de")
    IO.puts("Dashboard: #{email} / #{password}")
  end

  defp put({:ok, document}, id, fields), do: Document.put_block(document, id, fields)

  defp put(document, id, fields) when is_map(document),
    do: Document.put_block(document, id, fields)
end

NordlichtSeed.run()
