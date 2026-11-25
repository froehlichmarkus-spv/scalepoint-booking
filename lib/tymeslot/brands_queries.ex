defmodule Tymeslot.BrandsQueries do
  @moduledoc false

  import Ecto.Query

  alias Tymeslot.Auth.UserSchema
  alias Tymeslot.Profiles.ProfileSchema
  alias Tymeslot.Repo

  require Logger

  @spec profile_username(integer()) :: String.t() | nil
  def profile_username(id) do
    Repo.one(from p in ProfileSchema, where: p.user_id == ^id, select: p.username)
  rescue
    error ->
      Logger.warning("profile username lookup failed", error: Exception.message(error))
      nil
  end

  @spec user_email(integer()) :: String.t() | nil
  def user_email(id) do
    Repo.one(from u in UserSchema, where: u.id == ^id, select: u.email)
  rescue
    error ->
      Logger.warning("user email lookup failed", error: Exception.message(error))
      nil
  end

  @spec tenant_brand_rows() :: list()
  def tenant_brand_rows do
    case Repo.query("select key, document from tenant_brands", []) do
      {:ok, %{rows: rows}} when is_list(rows) -> rows
      _other -> []
    end
  rescue
    error ->
      Logger.warning("tenant brand overlay unavailable", error: Exception.message(error))
      []
  end
end
