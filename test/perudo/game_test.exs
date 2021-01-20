defmodule Perudo.GameTest do
  use ExUnit.Case
  doctest Perudo.Game

  alias Perudo.Game

  setup_all do
    {:ok,
     example_game: %Game{
       current_player: "bob",
       players: ["alice", "bob", "eve"],
       rounds: [
         %{
           bids: [{"alice", {2, 3}}],
           next_players: %{
             "alice" => "bob",
             "bob" => "eve",
             "eve" => "alice"
           }
         }
       ]
     }}
  end

  test "creates valid game from given players" do
    assert Game.new_game(["alice", "bob", "eve"]) == %Perudo.Game{
             current_player: "alice",
             players: ["alice", "bob", "eve"],
             rounds: [
               %{
                 bids: [],
                 next_players: %{
                   "alice" => "bob",
                   "bob" => "eve",
                   "eve" => "alice"
                 }
               }
             ]
           }
  end

  test "bid fails when dice type is wrong", state do
    assert {:error, _} = Game.bid(state[:example_game], 2, 7)
    assert {:error, _} = Game.bid(state[:example_game], 2, 1)
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
end
