defmodule PerudoWeb.GameLive do
  use PerudoWeb, :live_view

  alias PerudoWeb.Endpoint

  defp try_start_room(room, player) do
    case DynamicSupervisor.start_child(
           Perudo.GameSupervisor,
           {Perudo.GameServer,
            state: %{room: room, players: MapSet.new([player])}, name: via(room)}
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        IO.inspect(GenServer.call(pid, {:add_player, player}))
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, game: nil)}
  end

  @impl true
  def handle_params(%{"room" => room, "player" => player}, _uri, socket) do
    try_start_room(room, player)

    case socket.assigns[:room] do
      nil ->
        Endpoint.subscribe(room)

      previous ->
        Endpoint.unsubscribe(previous)
        Endpoint.subscribe(room)
    end

    {:noreply, assign(socket, room: room, player: player)}
  end

  @impl true
  def handle_event("start_game", _unsigned_params, socket) do
    GenServer.call(via(socket.assigns[:room]), :start_game)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_update, game}, socket) do
    {:noreply, assign(socket, game: game)}
  end

  @impl true
  def handle_info(%{event: "game_updated", payload: game}, socket) do
    {:noreply, assign(socket, game: game)}
  end

  defp via(name), do: {:via, Registry, {Perudo.GameRegistry, name}}

  @impl true
  def render(assigns) do
    ~L"""
    <div>HI THERE</div>
    <%= @game %>
    <button phx-click="start_game">-</button>
    <div><%= IO.puts(assigns.game) %></div>
    """
  end
end
