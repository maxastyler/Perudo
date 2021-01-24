defmodule Perudo.GameServer do
  @moduledoc """
  This module implements the GenServer that players connect to to play a game of perudo
  """
  use GenStateMachine

  alias Perudo.PubSub
  alias Perudo.Game

  def start_link(options) do
    {state, opts} = Keyword.pop(options, :state)
    GenStateMachine.start_link(__MODULE__, {:lobby, state}, opts)
  end

  @impl true
  def init({state, data}), do: {:ok, state, data}

  @impl true
  def handle_event({:call, from}, {:add_player, player}, :lobby, data) do
    new_data = update_in(data, [:players], &MapSet.put(&1, player))
    {:keep_state, new_data, {:reply, from, {:ok, new_data}}}
  end

  def handle_event({:call, from}, {:remove_player, player}, :lobby, data) do
    new_data = update_in(data, [:players], &MapSet.delete(&1, player))
    {:keep_state, new_data, {:reply, from, {:ok, new_data}}}
  end

  def handle_event({:call, from}, :start_game, :lobby, %{players: players} = data) do
    if MapSet.size(players) > 1 do
      new_data =
        Map.put(data, :game, Perudo.Game.new_game(MapSet.to_list(data.players)))
        |> broadcast_game_state()

      {:next_state, :in_game, new_data, {:reply, from, {:ok, new_data}}}
    else
      {:keep_state_and_data, {:reply, from, {:error, "can't start with less than two players"}}}
    end
  end

  def handle_event(
        {:call, from},
        {:move, player, {:bid, n, t}},
        :in_game,
        %{game: %Perudo.Game{current_player: current_player} = game} = data
      ) do
    if current_player == player do
      with {:ok, new_game} <- Game.bid(game, n, t) do
        {:keep_state, Map.put(data, :game, new_game) |> broadcast_game_state(),
         {:reply, from, {:ok, new_game}}}
      else
        {:error, e} -> {:keep_state_and_data, {:reply, from, {:error, e}}}
      end
    else
      {:keep_state_and_data,
       {:reply, from, {:error, "called from player who isn't current player"}}}
    end
  end

  def handle_event(
        {:call, from},
        {:move, player, :dudo},
        :in_game,
        %{game: %Perudo.Game{current_player: current_player} = game} = data
      ) do
    if current_player == player do
      with {:ok, new_game} <- Game.call_dudo(game) do
        case Map.put(data, :game, new_game) |> broadcast_game_state() do
          %{game: %Perudo.Game{winner: nil}} = d ->
            broadcast_dudo(d)
            {:keep_state, d, {:reply, from, {:ok, d}}}

          d ->
            {:next_state, :won, d, {:reply, from, {:ok, d}}}
        end
      else
        {:error, e} -> {:keep_state_and_data, {:reply, from, {:error, e}}}
      end
    else
      {:keep_state_and_data,
       {:reply, from, {:error, "called from player who isn't current player"}}}
    end
  end

  def handle_event({:call, from}, :broadcast_state, _, %{game: _} = data) do
    broadcast_game_state(data)
    {:keep_state_and_data, {:reply, from, {:ok, "broadcasted"}}}
  end

  def handle_event({:call, from}, _, _, _),
    do: {:keep_state_and_data, {:reply, from, {:error, "no match"}}}

  @doc """
  Broadcast a message when dudo has been called
  """
  def broadcast_dudo(%{room: room, game: game}) do
    [_, %{dice: dice} | _] = game.rounds

    dice_string = for {player, d} <- dice, into: "", do: "#{player}: #{inspect(d)}\n"

    PerudoWeb.Endpoint.broadcast(
      room,
      "dudo_called",
      "Dudo called!\nPlayers had:\n#{dice_string}"
    )
  end

  def broadcast_game_state(%{room: room, game: game} = data) do
    PerudoWeb.Endpoint.broadcast(room, "game_updated", game)
    data
  end

  def add_player(server, player) do
    GenStateMachine.call(via(server), {:add_player, player})
  end

  defp via(name), do: {:via, Registry, {Perudo.GameRegistry, name}}

  def start_server(name) do
    DynamicSupervisor.start_child(
      Perudo.GameSupervisor,
      {Perudo.GameServer, state: %{room: name, players: MapSet.new()}, name: via(name)}
    )
  end

  def call_name(name, call) do
    GenStateMachine.call(via(name), call)
  end
end
