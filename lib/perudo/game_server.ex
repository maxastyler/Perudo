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
  def init({state, data}) do
    {:ok, state, data}
  end

  @impl true
  def handle_event({:call, from}, {:add_player, player}, :lobby, data) do
    new_data = update_in(data, [:players], &MapSet.put(&1, player))
	{:keep_state, new_data, {:reply, from, {:ok, new_data}}}
  end

  def handle_event({:call, from}, {:remove_player, player}, :lobby, data) do
    new_data = update_in(data, [:players], &MapSet.delete(&1, player))
	{:keep_state, new_data, {:reply, from, {:ok, new_data}}}
  end

  def handle_event({:call, from}, :start_game, :lobby, data) do
	game = Perudo.Game.new_game(MapSet.to_list(data.players))
    {:next_state, :in_game, Map.put(data, :game, game), {:reply, from, "jo"}}
  end

  def add_player(server, player) do
    GenStateMachine.call(server, {:add_player, player})
  end
end
