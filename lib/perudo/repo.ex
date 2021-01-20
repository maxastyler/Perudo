defmodule Perudo.Repo do
  use Ecto.Repo,
    otp_app: :perudo,
    adapter: Ecto.Adapters.Postgres
end
