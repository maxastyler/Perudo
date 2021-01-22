defmodule Perudo.GameServer do
  @moduledoc """
  This module implements the GenServer that players connect to to play a game of perudo
  """
  use GenServer, restart: :transient

  alias Perudo.PubSub
  alias Perudo.Game

  def start_link(options) do
    {state, opts} = Keyword.pop(options, :state)
    GenServer.start_link(__MODULE__, state, opts)
  end

  @impl true
  def init(%{room: room, players: players}) do
    {:ok, %{room: room, players: players, started: false, game: nil}}
  end

  @impl true
  def handle_call({:add_player, player}, _from, %{game: nil} = state),
    do: {:reply, :added_player, update_in(state[:players], &MapSet.put(&1, player))}

  def handle_call({:add_player, _}, _from, state), do: {:reply, :game_started, state}

  @impl true
  def handle_call(:start_game, _from, %{game: nil} = state) do
    if MapSet.size(state[:players]) > 1 do
      game = Game.new_game(MapSet.to_list(state[:players]))
      PerudoWeb.Endpoint.broadcast(state[:room], "game_updated", game)
      {:reply, :started, put_in(state[:game], game)}
    else
      {:reply, {:error, "can't start until there are >1 players"}, state}
    end
  end
end
