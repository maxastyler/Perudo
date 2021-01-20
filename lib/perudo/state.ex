defmodule Perudo.State do
  @type player_name() :: String.t()
  @type dice_set :: [integer()]

  @type t() :: %__MODULE__{
          next_players: %{player_name() => player_name()},
          current_player: player_name(),
          dice: %{player_name() => dice_set}
        }

  @enforce_keys [:next_players, :turn]
  defstruct [:next_players, :current_player, :dice]
end
