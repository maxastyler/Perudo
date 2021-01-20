defmodule Perudo.Game do
  @moduledoc """
  This module holds the perudo game state and associated functions
  """
  alias Perudo.Game

  @default_max_dice 5

  @type player() :: String.t()
  @type dice_set :: [integer()]

  @typedoc """
  A bid is a pair of integers of {m, n} which corresponds to a bid: m dice with value n
  """
  @type bid :: {integer(), integer()}

  @type round :: %{
          next_players: %{player() => player()},
          bids: [{player(), bid}],
          dice: %{player() => [integer()]}
        }

  @type t() :: %__MODULE__{
          rounds: [round],
          current_player: player(),
          players: [player()]
        }

  @enforce_keys [:current_player, :players]
  defstruct [:current_player, players: [], rounds: []]

  @doc """
  Turn the list l into a map where each key maps to the next value in the list. 
  The last element of the list wraps to the first element.
  """
  @spec list_to_adjacency_map([t]) :: %{t => t}
  defp list_to_adjacency_map([first | _] = l) do
    Enum.zip(l, Enum.drop(l, 1) ++ [first]) |> Map.new()
  end

  @doc """
  Create a new game from the given players list.
  This function creates an adjacency map in the order that the list is
  and starts a new round with the first player being the first player in the list.
  """
  @spec new_game([player()]) :: t()
  def new_game([first | _] = players, starting_dice \\ @default_max_dice) do
    %Game{
      current_player: first,
      players: players,
      rounds: [
        %{
          next_players: list_to_adjacency_map(players),
          bids: [],
          dice:
            for(
              p <- players,
              into: %{},
              do: {p, for(_ <- 0..starting_dice, do: :rand.uniform(6))}
            )
        }
      ]
    }
  end

  @doc """
  Make a bid in the current game
  """
  @spec bid(t(), integer(), integer()) :: {:ok, t()} | {:error, String.t()}
  def bid(
        %{current_player: current_player, rounds: [current_round | _]} = game,
        num_dice,
        type_dice
      )
      when type_dice in 2..6 do
    next_player = get_in(current_round, [:next_players, current_player])

    {_, {previous_num_dice, previous_type_dice}} =
      case List.first(current_round.bids) do
        nil -> {0, {0, 0}}
        v -> v
      end

    cond do
      num_dice < previous_num_dice ->
        {:error, "Number of dice should always increase or stay the same"}

      num_dice == previous_num_dice and previous_type_dice >= type_dice ->
        {:error, "Type of dice should increase when number of dice stays the same"}

      :else ->
        {:ok,
         game
         |> put_in([Access.key(:current_player)], next_player)
         |> update_in([Access.key(:rounds), Access.at(0), :bids], fn bids ->
           [{current_player, {num_dice, type_dice}} | bids]
         end)}
    end
  end

  def bid(_, _, _) do
    {:error, "Dice type should be a number between 2 and 6"}
  end

  @doc """
  Call a perudo on the current game. Returns {:caller_wins, name} or {:caller_loses, name}
  with name being the name of the player who loses a die
  """
  @spec perudo(t()) :: {:caller_wins | :caller_loses, player()}
  def perudo(
        %Game{
          current_player: current_player,
          rounds: [%{bids: [{last_player, last_bid} | _], dice: dice} | _]
        }
      ) do
    case dice_satisfy_bid(dice, last_bid) do
      true -> {:caller_loses, current_player}
      false -> {:caller_wins, last_player}
    end
  end

  @doc """
  Check if the given dice satisfy the given bid
  """
  @spec dice_satisfy_bid(%{player() => [integer()]}, bid()) :: boolean()
  def dice_satisfy_bid(dice, {num_dice, type_dice}) do
    for(
      d <- Map.values(dice) |> Enum.concat(),
      d == type_dice or d == 1,
      reduce: 0,
      do: (acc -> acc + 1)
    ) >= num_dice
  end
end