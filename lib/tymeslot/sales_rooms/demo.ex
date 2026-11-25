defmodule Tymeslot.SalesRooms.Demo do
  @moduledoc """
  Local demo workspace. Lena Hartmann at Nordlicht Analytics is Pro.
  Mara Weber is Free, so the classic page can be compared with the sales room.
  """

  alias Tymeslot.Auth.UserSchema
  alias Tymeslot.Availability
  alias Tymeslot.Availability.Schedules
  alias Tymeslot.Integrations.Calendar.Management
  alias Tymeslot.MeetingTypes
  alias Tymeslot.Plans
  alias Tymeslot.Profiles.ProfileQueries
  alias Tymeslot.Profiles.ProfileSchema
  alias Tymeslot.Repo
  alias Tymeslot.SalesRooms
  alias Tymeslot.SalesRooms.Blocks
  alias Tymeslot.SalesRooms.Storage
  alias Tymeslot.Themes.Catalog

  @password "Nordlicht-Demo-2026"

  def password, do: @password

  def seed! do
    lena = ensure_user("lena.hartmann@nordlicht-analytics.de", "Lena Hartmann")
    mara = ensure_user("mara.weber@maraweber.de", "Mara Weber")
    {:ok, theme} = Catalog.key_to_id(:folio)

    lena_profile = ensure_profile(lena, "nordlicht", "Lena Hartmann", theme)
    mara_profile = ensure_profile(mara, "maraweber", "Mara Weber", theme)

    intro(lena_profile, "Gespräche, die eine Entscheidung tragen.", nordlicht_bio())
    intro(mara_profile, "Klartext für den nächsten Schritt.", mara_bio())

    open_week(lena_profile.id)
    open_week(mara_profile.id)
    maybe_calendar(lena)
    maybe_calendar(mara)

    _ = promote(lena)
    type = ensure_type(lena, "Strategiegespräch", "strategie", 45)
    _ = ensure_type(mara, "Kennenlernen", "kennenlernen", 30)

    portrait = write_png(720, 900, {17, 42, 68})
    _ = maybe_avatar(lena_profile, portrait)
    _ = maybe_avatar(mara_profile, write_png(720, 900, {70, 90, 110}))

    blocks = nordlicht_blocks(lena_profile.id)

    {:ok, _} =
      SalesRooms.save(lena.id, lena_profile.id, nil, nil, %{blocks: blocks, accent: "#1F6F68"})

    if type do
      {:ok, _} =
        SalesRooms.save(lena.id, lena_profile.id, nil, type.id, %{
          blocks: blocks,
          override: false
        })
    end

    Repo.update_all(
      from_profile(lena_profile.id),
      set: [booking_page_published_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )

    %{
      pro: "/nordlicht/strategie",
      free: "/maraweber/kennenlernen",
      editor: "/dashboard/sales-room",
      email: lena.email,
      password: @password
    }
  end

  defp ensure_user(email, name) do
    case Repo.get_by(UserSchema, email: email) do
      %UserSchema{} = user ->
        user

      nil ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        user =
          %UserSchema{}
          |> UserSchema.registration_changeset(%{
            email: email,
            name: name,
            password: @password,
            password_confirmation: @password
          })
          |> Ecto.Changeset.put_change(:verified_at, now)
          |> Ecto.Changeset.put_change(:onboarding_completed_at, now)
          |> Ecto.Changeset.put_change(:locale, "de")
          |> Repo.insert!()

        user
    end
  end

  defp ensure_profile(user, username, full_name, theme) do
    profile =
      case Repo.get_by(ProfileSchema, user_id: user.id) do
        %ProfileSchema{} = profile ->
          profile

        nil ->
          %ProfileSchema{}
          |> ProfileSchema.create_changeset(%{user_id: user.id, full_name: full_name})
          |> Repo.insert!()
      end

    {:ok, profile} = ProfileQueries.update_username(profile, username)

    profile
    |> ProfileSchema.theme_changeset(%{booking_theme: theme, has_custom_theme: false})
    |> Repo.update!()
  end

  defp intro(profile, headline, bio) do
    profile
    |> ProfileSchema.intro_changeset(%{headline: headline, bio: bio})
    |> Repo.update!()
  end

  defp open_week(profile_id) do
    _ = Schedules.create_default(profile_id)

    Availability.set_weekly_hours(profile_id, %{
      days: [1, 2, 3, 4, 5],
      start: "09:00",
      end: "17:00"
    })
  end

  defp maybe_calendar(user) do
    Management.insert_integration(%{
      user_id: user.id,
      name: "Demo calendar",
      provider: "demo",
      is_active: true,
      base_url: "https://demo.localhost",
      provider_account_email: user.email
    })
  rescue
    _ -> :ok
  end

  defp ensure_type(user, name, slug, minutes) do
    case MeetingTypes.create_meeting_type(%{
           user_id: user.id,
           name: name,
           slug: slug,
           duration_minutes: minutes,
           description: name
         }) do
      {:ok, type} -> type
      _ -> Repo.get_by(Tymeslot.MeetingTypes.MeetingTypeSchema, user_id: user.id, slug: slug)
    end
  end

  defp maybe_avatar(profile, path) do
    ext = ".png"

    with {:ok, stored} <- Storage.store_image(profile.id, path),
         {:ok, absolute} <- Storage.resolve(stored),
         {:ok, name} <-
           Tymeslot.Media.Uploads.store_atomically(
             absolute,
             "avatars/#{profile.id}",
             Tymeslot.Media.Uploads.stored_name(ext),
             %{operation: :demo_avatar}
           ) do
      profile
      |> ProfileSchema.avatar_changeset(%{avatar: name})
      |> Repo.update()
    end
  end

  defp nordlicht_blocks(profile_id) do
    logo = store_ok(profile_id, write_png(640, 160, {17, 30, 50}))

    photos =
      Enum.map([{32, 78, 88}, {70, 110, 120}, {20, 50, 70}, {90, 130, 125}], fn color ->
        store_ok(profile_id, write_png(960, 720, color))
      end)

    logos =
      Enum.map([{40, 55, 70}, {60, 80, 90}, {30, 70, 75}], fn color ->
        store_ok(profile_id, write_png(480, 180, color))
      end)

    pdf = write_pdf()
    {:ok, brochure} = Storage.store_pdf(profile_id, pdf)

    Blocks.blank()
    |> Blocks.put_enabled("hero", true)
    |> Blocks.put_content("hero", %{
      "headline" => "Entscheidungen, die nach dem Termin noch stehen.",
      "subline" =>
        "Nordlicht Analytics hilft Führungsteams, aus verstreuten Zahlen eine klare nächste Bewegung zu machen.",
      "logo_path" => logo,
      "logo_alt" => "Nordlicht Analytics",
      "show_profile_image" => false
    })
    |> Blocks.put_enabled("benefits", true)
    |> Blocks.put_content("benefits", %{
      "items" => [
        %{"id" => "b1", "text" => "Eine Frage, die das Meeting trägt."},
        %{"id" => "b2", "text" => "Die drei Zahlen, die wirklich entscheiden."},
        %{"id" => "b3", "text" => "Ein nächster Schritt mit Namen und Datum."}
      ]
    })
    |> Blocks.put_enabled("gallery", true)
    |> Blocks.put_content("gallery", %{
      "images" =>
        photos
        |> Enum.with_index(1)
        |> Enum.map(fn {path, index} ->
          %{
            "id" => "g#{index}",
            "path" => path,
            "alt" => "Arbeitsbild #{index} aus einem Nordlicht-Workshop"
          }
        end)
    })
    |> Blocks.put_enabled("video", true)
    |> Blocks.put_content("video", %{
      "url" => "https://vimeo.com/76979871",
      "title" => "Zwei Minuten, worum es im Gespräch geht"
    })
    |> Blocks.put_enabled("brochures", true)
    |> Blocks.put_content("brochures", %{
      "files" => [
        %{
          "id" => "brief",
          "path" => brochure,
          "title" => "Gesprächsleitfaden",
          "filename" => "Gespraechsleitfaden.pdf",
          "bytes" => 0
        }
      ]
    })
    |> Blocks.put_enabled("testimonials", true)
    |> Blocks.put_content("testimonials", %{
      "items" => [
        %{
          "id" => "t1",
          "quote" => "Wir gingen mit einer offenen Liste hinein und mit einem Beschluss hinaus.",
          "name" => "Jonas Keller",
          "role" => "Geschäftsführung, Hafenwerk"
        }
      ]
    })
    |> Blocks.put_enabled("logos", true)
    |> Blocks.put_content("logos", %{
      "items" =>
        logos
        |> Enum.with_index(1)
        |> Enum.map(fn {path, index} ->
          %{
            "id" => "l#{index}",
            "path" => path,
            "alt" => "Kundenlogo #{index}",
            "name" => "Haus #{index}"
          }
        end)
    })
    |> Blocks.put_enabled("faq", true)
    |> Blocks.put_content("faq", %{
      "items" => [
        %{
          "id" => "f1",
          "question" => "Wie lange dauert das Gespräch?",
          "answer" => "45 Minuten. Danach haben Sie einen nächsten Schritt, kein Protokoll."
        },
        %{
          "id" => "f2",
          "question" => "Muss ich Unterlagen schicken?",
          "answer" => "Nein. Der Leitfaden reicht. Wer Zahlen dabei hat, bringt sie mit."
        }
      ]
    })
    |> Blocks.put_enabled("cta", true)
    |> Blocks.put_content("cta", %{
      "headline" => "Wann passt es?",
      "text" => "Wählen Sie eine Zeit. Der Kalender bleibt die ganze Seite über in Reichweite.",
      "button_label" => "Termin wählen"
    })
  end

  defp store_ok(profile_id, path) do
    case Storage.store_image(profile_id, path) do
      {:ok, stored} -> stored
      _ -> nil
    end
  end

  defp nordlicht_bio do
    "Lena Hartmann führt Strategiegespräche für Teams, die eine Zahlensammlung in eine Entscheidung übersetzen wollen."
  end

  defp mara_bio do
    "Mara Weber bietet ein kurzes Kennenlernen. Profilbild, ein Satz, dann der Kalender."
  end

  defp from_profile(id) do
    import Ecto.Query
    from(p in ProfileSchema, where: p.id == ^id)
  end

  defp write_pdf do
    path = Path.join(System.tmp_dir!(), "nordlicht-#{System.unique_integer([:positive])}.pdf")

    File.write!(
      path,
      "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 400]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n"
    )

    path
  end

  defp promote(user) do
    Plans.upsert_entitlement(%{
      "data" => %{
        "external_user_id" => "booking:#{user.id}",
        "plan" => "pro",
        "status" => "active"
      },
      "version" => 1
    })

    Plans.invalidate(user.id)
  end

  defp write_png(width, height, {r, g, b}) do
    raw =
      for y <- 0..(height - 1), into: <<>> do
        shift = div(y * 36, max(height, 1))
        band = if rem(div(y, 18), 7) == 0, do: 18, else: 0

        <<0>> <>
          :binary.copy(
            <<min(r + shift, 255), min(g + shift + band, 255), min(b + shift, 255)>>,
            width
          )
      end

    compressed = :zlib.compress(raw)

    chunks =
      chunk("IHDR", <<width::32, height::32, 8, 2, 0, 0, 0>>) <>
        chunk("IDAT", compressed) <> chunk("IEND", "")

    path = Path.join(System.tmp_dir!(), "nordlicht-#{System.unique_integer([:positive])}.png")
    File.write!(path, <<137, 80, 78, 71, 13, 10, 26, 10>> <> chunks)
    path
  end

  defp chunk(type, data) do
    crc = :erlang.crc32(type <> data)
    <<byte_size(data)::32, type::binary, data::binary, crc::32>>
  end
end
