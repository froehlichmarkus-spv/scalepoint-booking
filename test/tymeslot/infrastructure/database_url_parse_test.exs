defmodule Tymeslot.Infrastructure.DatabaseUrlParseTest do
  @moduledoc """
  `start-docker.sh` used to split DATABASE_URL with a regex that stopped at
  the first `/` or `@`. A password containing those characters, or `#`, `?`
  or `%`, was parsed as the host and the script aborted. The redaction regex
  had the same hole, so the password could land in the log.

  Discrete DATABASE_HOST, DATABASE_PORT, POSTGRES_USER, POSTGRES_DB and
  POSTGRES_PASSWORD still win when the operator set them, and they still
  work when no URL is set.
  """

  use ExUnit.Case, async: true

  @moduletag :infrastructure

  @parser Path.expand("../../../scripts/database-url.sh", __DIR__)
  @script Path.expand("../../../start-docker.sh", __DIR__)

  test "the entrypoint no longer splits the URL on a slash inside the password" do
    script = File.read!(@script)

    refute script =~ ~r/\[\^@\/\]/
    assert script =~ "database-url.sh"
    assert script =~ "redact_database_url"
    assert script =~ "apply_discrete_database_overrides"
  end

  test "percent-encoded and raw special characters round-trip, and the log is redacted" do
    password = "p/a:s@s#w?o%rd"
    encoded = "p%2Fa%3As%40s%23w%3Fo%25rd"

    url = "ecto://booking:#{encoded}@postgres:5432/booking?sslmode=require"

    fields =
      bash("""
      parse_database_url #{shell_quote(url)}
      printf '%s\\0%s\\0%s\\0%s\\0%s\\0%s\\0' \\
        "$PARSED_DB_USER" "$PARSED_DB_PASSWORD" "$PARSED_DB_HOST" \\
        "$PARSED_DB_PORT" "$PARSED_DB_NAME" "$PARSED_DB_QUERY"
      printf '%s' "$(redact_database_url #{shell_quote(url)})"
      """)

    assert fields["user"] == "booking"
    assert fields["password"] == password
    assert fields["host"] == "postgres"
    assert fields["port"] == "5432"
    assert fields["name"] == "booking"
    assert fields["query"] == "sslmode=require"
    assert fields["redacted"] == "ecto://***:***@postgres:5432/booking?sslmode=require"
    refute fields["redacted"] =~ password
    refute fields["redacted"] =~ encoded
  end

  test "a raw slash, at-sign, hash or question mark in the password stays in the password" do
    url = "ecto://booking:p/ass:w@rd#x?y@db.internal:5432/booking"

    fields = parse(url)

    assert fields["password"] == "p/ass:w@rd#x?y"
    assert fields["host"] == "db.internal"
    assert fields["port"] == "5432"
    refute fields["redacted"] =~ "p/ass"
    refute fields["redacted"] =~ "#x"
  end

  test "an IPv6 host and a URL without credentials still parse" do
    ipv6 = parse("postgres://user:secret@[::1]:5432/db")
    assert ipv6["host"] == "::1"
    assert ipv6["port"] == "5432"
    assert ipv6["redacted"] == "postgres://***:***@[::1]:5432/db"

    plain = parse("postgres://db.internal:5432/booking")
    assert plain["host"] == "db.internal"
    assert plain["user"] == ""
    assert plain["password"] == ""
    assert plain["redacted"] == "postgres://db.internal:5432/booking"
  end

  test "operator-set discrete variables replace the URL and are not overwritten" do
    output =
      bash("""
      DATABASE_URL='ecto://fromurl:frompass@from.example:5432/fromdb'
      DATABASE_HOST_SET=1 DATABASE_HOST=discrete.example
      DATABASE_PORT_SET=1 DATABASE_PORT=6543
      POSTGRES_USER_SET=1 POSTGRES_USER=discrete_user
      POSTGRES_DB_SET=1 POSTGRES_DB=discrete_db
      POSTGRES_PASSWORD_SET=1 POSTGRES_PASSWORD='p/a@s:s#w?%'
      parse_database_url "$DATABASE_URL"
      apply_discrete_database_overrides
      built=$(build_database_url)
      printf '%s\\0%s\\0%s\\0%s\\0' \\
        "$POSTGRES_PASSWORD" "$PARSED_DB_HOST" "$PARSED_DB_PORT" "$built"
      """)

    assert output["password"] == "p/a@s:s#w?%"
    assert output["host"] == "discrete.example"
    assert output["port"] == "6543"

    assert output["built"] =~
             "ecto://discrete_user:p%2Fa%40s%3As%23w%3F%25@discrete.example:6543/discrete_db"

    refute output["built"] =~ "frompass"
  end

  test "a password only present in the URL is kept when the discrete variables were not set" do
    fields =
      bash("""
      parse_database_url 'ecto://booking:only-in-url@postgres:5432/booking'
      POSTGRES_PASSWORD=tymeslot
      apply_discrete_database_overrides
      printf '%s' "$PARSED_DB_PASSWORD"
      """)

    assert fields["password"] == "only-in-url"
  end

  defp parse(url) do
    bash("""
    parse_database_url #{shell_quote(url)}
    printf '%s\\0%s\\0%s\\0%s\\0%s\\0%s\\0' \\
      "$PARSED_DB_USER" "$PARSED_DB_PASSWORD" "$PARSED_DB_HOST" \\
      "$PARSED_DB_PORT" "$PARSED_DB_NAME" "$PARSED_DB_QUERY"
    printf '%s' "$(redact_database_url #{shell_quote(url)})"
    """)
  end

  defp bash(body) do
    script = """
    set -eu
    . #{shell_quote(@parser)}
    #{body}
    """

    {output, 0} = System.cmd("/bin/bash", ["-c", script], env: [{"LANG", "C.UTF-8"}])
    decode(output)
  end

  defp decode(output) do
    parts = :binary.split(output, <<0>>, [:global])

    case parts do
      [password] ->
        %{"password" => password}

      [password, host, port, built, ""] ->
        %{
          "password" => password,
          "host" => host,
          "port" => port,
          "built" => built
        }

      [user, password, host, port, name, query, redacted] ->
        %{
          "user" => user,
          "password" => password,
          "host" => host,
          "port" => port,
          "name" => name,
          "query" => query,
          "redacted" => redacted
        }
    end
  end

  defp shell_quote(value) do
    "'" <> String.replace(value, "'", "'\\''") <> "'"
  end
end
