defmodule Perudo.Game do
  @moduledoc """
  This module holds the perudo game state and associated functions
  """
  alias Perudo.Game
  import Access, only: [key: 1, key: 2, at: 1]

  @default_max_dice 5

  @type player() :: String.t()
  @type dice_set :: [integer()]

  @typedoc """
  A bid is a pair of integers of {m, n} which corresponds to a bid: m dice with value n
  """
  @type bid :: {integer(), integer()}

  @type round :: %{
          palafico: player() | nil,
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
          palafico: nil,
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

  @spec update_game_with_bid(t(), player(), bid()) :: t()
  defp update_game_with_bid(game, bidder, bid) do
    next_player = get_in(game, [key(:rounds), at(0), :next_players, bidder])

    game
    |> put_in([key(:current_player)], next_player)
    |> update_in([key(:rounds), at(0), :bids], fn bids ->
      [{bidder, bid} | bids]
    end)
  end

  @doc """
  Make a bid in the current game
  """
  @spec bid(t(), integer(), integer()) :: {:ok, t()} | {:error, String.t()}
  def bid(
        %{current_player: current_player, rounds: [%{palafico: nil} = current_round | _]} = game,
        num_dice,
        type_dice
      )
      when type_dice in 2..6 do
    {_, {previous_num_dice, previous_type_dice}} =
      case List.first(current_round.bids) do
        nil -> {0, {0, 0}}
        v -> v
      end

    cond do
      previous_type_dice == 1 and num_dice != previous_num_dice * 2 + 1 ->
        {:error, "When moving from aces to normal, the number of dice should increase by (n*2+1)"}

      previous_type_dice == 1 and num_dice == previous_num_dice * 2 + 1 ->
        {:ok, update_game_with_bid(game, current_player, {num_dice, type_dice})}

      num_dice < previous_num_dice ->
        {:error, "Number of dice should always increase or stay the same when type is the same"}

      num_dice == previous_num_dice and previous_type_dice >= type_dice ->
        {:error, "Type of dice should increase when number of dice stays the same"}

      :else ->
        {:ok, update_game_with_bid(game, current_player, {num_dice, type_dice})}
    end
  end

  def bid(
        %{current_player: current_player, rounds: [%{palafico: nil} = current_round | _]} = game,
        num_dice,
        1
      ) do
    case List.first(current_round.bids) do
      nil ->
        {:error, "Can't call aces at the start of a round when not palafico"}

      {_, {previous_num_dice, 1}} when previous_num_dice >= num_dice ->
        {:error, "Number of dice should always increase or stay the same when type is the same"}

      {_, {previous_num_dice, _}} when ceil(previous_num_dice / 2) == num_dice ->
        {:ok, update_game_with_bid(game, current_player, {num_dice, 1})}

      _ ->
        {:error, "When moving to aces from other types, number of dice should half rounded up"}
    end
  end

  # these rules are for the palafico round, where aces aren't special
  def bid(
        %{current_player: current_player, rounds: [current_round | _]} = game,
        num_dice,
        type_dice
      ) do
    {_, {previous_num_dice, previous_type_dice}} =
      case List.first(current_round.bids) do
        nil -> {0, {0, 0}}
        v -> v
      end

    # is current player palafico?
    if length(current_round.dice[current_player]) == 1 do
      cond do
        num_dice < previous_num_dice ->
          {:error, "Number of dice should always increase or stay the same when type is the same"}

        num_dice == previous_num_dice and previous_type_dice >= type_dice ->
          {:error, "Type of dice should increase when number of dice stays the same"}

        :else ->
          {:ok, update_game_with_bid(game, current_player, {num_dice, type_dice})}
      end
    else
      cond do
        type_dice != previous_type_dice ->
          {:error, "When in a palafico round and you're not palafico, you can't change dice type"}

        num_dice <= previous_num_dice ->
          {:error, "Dice number should be increasing"}

        :else ->
          {:ok, update_game_with_bid(game, current_player, {num_dice, type_dice})}
      end
    end
  end

  def bid(_, _, _) do
    {:error, "Dice type should be a number between 1 and 6"}
  end

  @doc """
  Call a dudo on the current game. Returns {:caller_wins, name} or {:caller_loses, name}
  with name being the name of the player who loses a die
  """
  @spec dudo(t()) :: {:caller_wins | :caller_loses, player()}
  def dudo(%Game{
        current_player: current_player,
        rounds: [%{bids: [{last_player, last_bid} | _], dice: dice, palafico: palafico} | _]
      }) do
    case dice_satisfy_bid(dice, last_bid, palafico != nil) do
      true -> {:caller_loses, current_player}
      false -> {:caller_wins, last_player}
    end
  end

  @doc """
  Check if the given dice satisfy the given bid
  """
  @spec dice_satisfy_bid(%{player() => [integer()]}, bid(), boolean()) :: boolean()
  def dice_satisfy_bid(dice, {num_dice, type_dice}, palafico) do
    for(
      d <- Map.values(dice) |> Enum.concat(),
      d == type_dice or (!palafico and d == 1),
      reduce: 0,
      do: (acc -> acc + 1)
    ) >= num_dice
  end

  @doc """
  Get the possible actions for the current game (you can only bid when it's the start of your turn)
  :bid_restricted means you can make a bid of a type in 2..6
  :bid_unrestricted means you can make a bid of a type in 1..6
  :bid_ace will half the current value
  :dudo calls a dudo on the current game
  """
  # first bid of the round, no palafico
  def get_actions(%Game{rounds: [%{bids: [], palafico: nil} | _]}) do
    [:bid_restricted]
  end

  # first bid of the round, palafico
  def get_actions(%Game{
        current_player: current_player,
        rounds: [%{bids: [], palafico: palafico} | _]
      })
      when current_player == palafico do
    [:bid_unrestricted]
  end

  # bid in a non-palafico round
  def get_actions(%Game{rounds: [%{palafico: nil} | _]}) do
    [:bid_restricted, :bid_ace, :dudo]
  end

  # bid in a palafico round
  def get_actions(_) do
    [:bid_unrestricted, :dudo]
  end
end
