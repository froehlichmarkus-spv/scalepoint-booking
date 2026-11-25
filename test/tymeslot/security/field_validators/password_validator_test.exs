defmodule Tymeslot.Security.FieldValidators.PasswordValidatorTest do
  use Tymeslot.DataCase, async: true

  @moduletag :security

  alias Tymeslot.Security.FieldValidators.PasswordValidator

  describe "rules/0" do
    # rules/0 is what the on-screen checklist renders from, so a rule that is
    # enforced but not listed here (or listed but not enforced) is exactly the
    # drift that let a password pass every visible rule and still be rejected.
    test "every advertised rule is one validate/2 actually enforces" do
      valid = "StrongPass123!"
      assert :ok = PasswordValidator.validate(valid)

      for %{key: key, pattern: pattern} <- PasswordValidator.rules() do
        assert Regex.match?(Regex.compile!(pattern), valid),
               "a password validate/2 accepts fails the advertised #{key} rule"
      end
    end

    test "a password satisfying every advertised rule is accepted" do
      # Built to satisfy the rules as stated, not to a hardcoded example, so
      # this fails if a rule is ever enforced without being advertised.
      password = "aA1!" <> String.duplicate("x", PasswordValidator.min_length())

      for %{pattern: pattern} <- PasswordValidator.rules() do
        assert Regex.match?(Regex.compile!(pattern), password)
      end

      assert :ok = PasswordValidator.validate(password)
    end
  end

  describe "validate/2" do
    test "returns :ok for valid passwords without composition rules" do
      assert :ok = PasswordValidator.validate("StrongPass123!")
      assert :ok = PasswordValidator.validate("Another@456")
      assert :ok = PasswordValidator.validate("correct horse")
      assert :ok = PasswordValidator.validate("nouppercase")
    end

    test "rejects a common or breached password" do
      assert {:error, "This password is too common. Try a short phrase only you would know."} =
               PasswordValidator.validate("password")

      assert {:error, "This password is too common. Try a short phrase only you would know."} =
               PasswordValidator.validate("Password")
    end

    test "rejects a password that contains the email name" do
      assert {:error, "Choose a password that does not contain your email name."} =
               PasswordValidator.validate("lena-harbor-2026", email: "lena@nordlicht-mail.io")
    end

    test "accepts a password that does not contain the email name" do
      assert :ok =
               PasswordValidator.validate("correct horse battery",
                 email: "lena@nordlicht-mail.io"
               )
    end

    test "returns error for short password" do
      assert {:error, "Password must be at least 8 characters long"} =
               PasswordValidator.validate("Sh0rt!")
    end

    # bcrypt reads only the first 72 bytes, so anything past them would be
    # accepted but silently ignored when the password is checked.
    test "accepts a password of exactly 72 bytes" do
      assert :ok = PasswordValidator.validate("Aa1!" <> String.duplicate("a", 68))
    end

    test "rejects a password longer than 72 bytes" do
      assert {:error, message} =
               PasswordValidator.validate("Aa1!" <> String.duplicate("a", 69))

      assert message =~ "at most 72 bytes"
    end

    test "counts the cap in bytes, not characters" do
      # 40 characters, but "é" takes two bytes each: 4 + 36 * 2 = 76 bytes.
      password = "Aa1!" <> String.duplicate("é", 36)
      assert String.length(password) == 40

      assert {:error, message} = PasswordValidator.validate(password)
      assert message =~ "at most 72 bytes"
    end

    test "supports a custom min_length option" do
      assert :ok = PasswordValidator.validate("Sh0rt!", min_length: 5)

      assert {:error, "Password must be at least 15 characters long"} =
               PasswordValidator.validate("Sh0rt!", min_length: 15)
    end

    test "returns error for non-binary values" do
      assert {:error, "Password must be a text value"} = PasswordValidator.validate(123)
    end

    test "returns error for empty or nil password" do
      assert {:error, "Password is required"} = PasswordValidator.validate("")
      assert {:error, "Password is required"} = PasswordValidator.validate(nil)
    end
  end

  describe "validate_confirmation/3" do
    test "returns :ok when confirmation matches" do
      assert :ok = PasswordValidator.validate_confirmation("Pass123!", "Pass123!")
    end

    test "returns error when confirmation doesn't match" do
      assert {:error, "Password confirmation does not match"} =
               PasswordValidator.validate_confirmation("Pass123!", "Different123!")
    end

    test "returns error when confirmation is missing" do
      assert {:error, "Password confirmation is required"} =
               PasswordValidator.validate_confirmation("Pass123!", "")

      assert {:error, "Password confirmation is required"} =
               PasswordValidator.validate_confirmation("Pass123!", nil)
    end
  end
end
