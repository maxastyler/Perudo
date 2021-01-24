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
    case GS.call_name(socket.assigns[:room], :start_game) do
      {:error, e} -> {:noreply, put_flash(socket, :error, e)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("make_bid", %{"bid" => %{"amount" => amount, "type" => type}}, socket) do
    with {amount, _} <- Integer.parse(amount),
         {type, _} <- Integer.parse(type),
         {:ok, _} <-
           GS.call_name(
             socket.assigns[:room],
             {:move, socket.assigns[:player], {:bid, amount, type}}
           ) do
      {:noreply, socket}
    else
      {:error, e} -> {:noreply, put_flash(socket, :error, e)}
      :error -> {:noreply, put_flash(socket, :error, "enter a number")}
      _ -> {:noreply, put_flash(socket, :error, "unhandled error")}
    end
  end

  def handle_event("dudo", _params, socket) do
    case GS.call_name(socket.assigns[:room], {:move, socket.assigns[:player], :dudo}) do
      {:error, e} -> {:noreply, put_flash(socket, :error, e)}
      {:ok, _} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:game_update, game}, socket) do
    {:noreply, assign(socket, game: game)}
  end

  @impl true
  def handle_info(%{event: "game_updated", payload: game}, socket) do
    {:noreply, assign(socket, game: game) |> clear_flash()}
  end

  def handle_info(%{event: "dudo_called", payload: message}, socket) do
    {:noreply, put_flash(socket, :info, message)}
  end

  def handle_info(%{event: "server_halting", payload: _}, socket) do
    {:noreply, put_flash(socket, :error, "Game timed out. Refresh page to continue")}
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
          winner: nil,
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
  def render_game(
        %Perudo.Game{
          winner: winner},
        player
      ) do
    assigns = %{
      winner: winner
    }

    ~L"""
    <div><h2>Winner is: <%= @winner %></h2></div>
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

  def render_dice(player, nil) do
  assigns = %{}

  ~L"""
    """
  end

  end
  def render_dice(player, dice) do
    assigns = %{player: player, dice: dice}

    ~L"""
    <div><tr class="player-row" id="<%= @player %>">
    <td>Your dice: </td>
    <%= for d <- @dice do %>
    <td><%= d %></td>
    <% end %>
    </tr>
    </div>
    """
  end
end
