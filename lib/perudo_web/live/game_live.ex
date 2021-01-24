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

    GS.call_name(room, :broadcast_state)

    {:noreply, assign(socket, room: room, player: player)}
  end

  @impl true
  def handle_event("start_game", _unsigned_params, socket) do
    GS.call_name(socket.assigns[:room], :start_game)
    {:noreply, socket}
  end

  def handle_event("make_bid", %{"bid" => %{"amount" => amount, "type" => type}}, socket) do
    GS.call_name(
      socket.assigns[:room],
      {:move, socket.assigns[:player], {:bid, String.to_integer(amount), String.to_integer(type)}}
    )

    {:noreply, socket}
  end

  def handle_event("dudo", _params, socket) do
    GS.call_name(socket.assigns[:room], {:move, socket.assigns[:player], :dudo})
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
    <h2>Playing as: <%= @player %></h2>
    <div><%= render_game(@game, @player) %></div>
    """
  end

  def render_game(nil, _) do
    assigns = %{}

    ~L"""
    NO GAME AVAILABLE
    <button phx-click="start_game">Start game</button>    
    """
  end

  def render_game(
        %Perudo.Game{
          current_player: current_player,
          rounds: [%{bids: bids, dice: dice} = current | _]
        } = game,
        player
      ) do
    {current_num, current_type} =
      case bids do
        [] -> {nil, nil}
        [{_, b} | _] -> b
      end

    assigns = %{
      dice: dice,
      current_num: current_num,
      current_type: current_type,
      current_player: current_player,
      player: player
    }

    ~L"""
    <div><h3>Current player: <%= @current_player %></h3></div>
    <div><h3>Current bid: 
    <%= if @current_num == nil do %>
    None
    <% else %>
    <%= @current_num %> of <%= @current_type %>
    <% end %>
    </h3></div>
    <%= render_dice(@player, dice[@player]) %>
    <%= if @player == @current_player do %>
    <%= render_game_controls() %>
    <% end %>
    """
  end

  def render_game_controls() do
    assigns = %{}

    ~L"""
    <div>
    <%= f = form_for :bid, "#", [phx_submit: "make_bid"] %>
    <%= label f, :amount %>
    <%= number_input f, :amount %>
    <%= label f, :type %>
    <%= number_input f, :type %>
    <%= submit "Bid" %>
    </form>
    </div>
    <div>
    <button phx-click="dudo">Call Dudo</button>    
    </div>
    """
  end

  def render_dice(player, dice) do
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
