defmodule Perudo.GameTest do
  use ExUnit.Case
  doctest Perudo.Game

  alias Perudo.Game

  @default_dice %{"alice" => [1, 1, 1, 1, 1], "bob" => [1, 1, 1, 1, 1], "eve" => [1, 1, 1, 1, 1]}

  defp put_dice(game, dice \\ @default_dice),
    do: put_in(game, [Access.key(:rounds), Access.at(0), :dice], dice)

  setup_all do
    {:ok,
     example_game: %Game{
       current_player: "bob",
       players: ["alice", "bob", "eve"],
       rounds: [
         %{
           palafico: nil,
           bids: [{"alice", {2, 3}}],
           next_players: %{
             "alice" => "bob",
             "bob" => "eve",
             "eve" => "alice"
           },
           dice: @default_dice
         }
       ]
     }}
  end

  test "creates valid game from given players", state do
    assert Game.new_game(["alice", "bob", "eve"]) |> put_dice() ==
             put_in(state[:example_game], [Access.key(:current_player)], "alice")
             |> pop_in([Access.key(:rounds), Access.at(0), :bids, Access.at(0)])
             |> elem(1)
  end

  test "bid fails when dice type is wrong", state do
    assert {:error, _} = Game.bid(state[:example_game], 2, 7)
    assert {:error, _} = Game.bid(state[:example_game], 2, 0)
  end

  test "bid fails when bid is less than previous", state do
    assert {:error, _} = Game.bid(state[:example_game], 2, 3)
    assert {:error, _} = Game.bid(state[:example_game], 2, 2)
    assert {:error, _} = Game.bid(state[:example_game], 1, 5)
  end

  test "bid works when number of dice is greater than previous", state do
    new_state =
      state[:example_game]
      |> put_in([Access.key(:current_player)], "eve")
      |> update_in([Access.key(:rounds), Access.at(0), :bids], fn b ->
        [{state[:example_game].current_player, {3, 2}} | b]
      end)

    assert {:ok, new_state} == Game.bid(state[:example_game], 3, 2)
  end

  test "bid works when number of dice is equal to previous and type is greater", state do
    new_state =
      state[:example_game]
      |> put_in([Access.key(:current_player)], "eve")
      |> update_in([Access.key(:rounds), Access.at(0), :bids], fn b ->
        [{state[:example_game].current_player, {2, 4}} | b]
      end)

    assert {:ok, new_state} == Game.bid(state[:example_game], 2, 4)
  end

  test "bid works when both numbers are greater than previous", state do
    new_state =
      state[:example_game]
      |> put_in([Access.key(:current_player)], "eve")
      |> update_in([Access.key(:rounds), Access.at(0), :bids], fn b ->
        [{state[:example_game].current_player, {5, 4}} | b]
      end)

    assert {:ok, new_state} == Game.bid(state[:example_game], 5, 4)
  end

  test "bid works when there's no previous bid", state do
    new_state =
      state[:example_game]
      |> put_in([Access.key(:current_player)], "eve")
      |> put_in(
        [Access.key(:rounds), Access.at(0), :bids],
        [{state[:example_game].current_player, {3, 2}}]
      )

    assert {:ok, new_state} ==
             Game.bid(
               put_in(state[:example_game], [Access.key(:rounds), Access.at(0), :bids], []),
               3,
               2
             )
  end

  test "dice satisfy function works" do
    assert Game.dice_satisfy_bid(@default_dice, {3, 2}, false)
    assert Game.dice_satisfy_bid(%{"a" => [1, 5, 2, 3], "b" => [1, 1]}, {4, 5}, false)
    refute Game.dice_satisfy_bid(%{"a" => [1, 5, 2, 3], "b" => [1, 1]}, {5, 5}, false)
    assert Game.dice_satisfy_bid(%{"a" => [1, 5, 2, 3], "b" => [1, 1]}, {3, 1}, true)
    refute Game.dice_satisfy_bid(%{"a" => [1, 5, 2, 3], "b" => [1, 1]}, {4, 1}, true)
    refute Game.dice_satisfy_bid(%{"a" => [1, 5, 2, 3], "b" => [1, 1]}, {4, 5}, true)
  end

  test "calling dudo returns expected results", state do
    assert Game.dudo(state[:example_game]) == {:caller_loses, "bob"}

    assert put_in(state[:example_game], [Access.key(:rounds), Access.at(0), :dice], %{
             "alice" => [2, 2, 4],
             "bob" => [2, 5],
             "eve" => [3, 4, 5]
           })
           |> Game.dudo() == {:caller_wins, "alice"}
  end
end
