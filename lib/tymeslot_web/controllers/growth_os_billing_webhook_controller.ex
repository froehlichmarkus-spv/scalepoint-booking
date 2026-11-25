defmodule TymeslotWeb.GrowthOsBillingWebhookController do
  @moduledoc """
  Receives signed entitlement pushes from growth-os-billing.

  Answers 2xx only after the entitlement row commits. A bad signature is 400.
  A processing error is 500 so billing retries. This is not the Stripe
  Connect endpoint and it does not read subscription events from
  `/webhooks/stripe`.
  """

  use TymeslotWeb, :controller

  alias Tymeslot.Plans.Webhook

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, _params) do
    raw = conn.assigns[:raw_body] || ""
    timestamp = header(conn, "x-gos-timestamp")
    signature = header(conn, "x-gos-signature")

    case Webhook.verify(raw, timestamp, signature) do
      :ok ->
        case Webhook.process(raw) do
          {:ok, _} -> send_resp(conn, 200, "")
          {:error, _} -> send_resp(conn, 500, "")
        end

      {:error, :not_configured} ->
        send_resp(conn, 503, "")

      {:error, :invalid_signature} ->
        send_resp(conn, 400, "")
    end
  end

  defp header(conn, name) do
    conn |> get_req_header(name) |> List.first()
  end
end
