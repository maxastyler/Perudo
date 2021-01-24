defmodule PerudoWeb.GameLive do
  use PerudoWeb, :live_view

  alias PerudoWeb.Endpoint
  alias Perudo.GameServer, as: GS

  defp try_start_room(room, player) do
    GS.start_server(room)
    GS.add_player(room, player)
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
    GS.call_name(socket.assigns[:room], :start_game)
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

  @impl true
  def render(assigns) do
    ~L"""
    <div><%= render_game(@game) %></div>
    <button phx-click="start_game">Start game</button>
    """
  end

  def render_game(nil) do
    assigns = %{}

    ~L"""
    NO GAME AVAILABLE
    """
  end

  def render_game(%Perudo.Game{rounds: [%{dice: dice} = current | _]} = game) do
    assigns = %{dice: dice}

    ~L"""
    <div><%= for d <- dice do %>
    <%= render_dice(d) %>
    <% end %></div>
    """
  end

  def render_dice({player, dice}) do
    assigns = %{player: player, dice: dice}

    ~L"""
    <div><tr class="player-row" id="<%= @player %>">
    <td><%= @player %></td>
    <%= for d <- @dice do %>
    <td><%= d %></td>
    <% end %>
    </tr>
    </div>
    """
  end
end
