defmodule PersonalFinance.CurrencyUtils do
  def format_money(nil), do: "R$ 0,00"

  def format_money(value) when is_float(value) or is_integer(value) do
    formatted_value = :erlang.float_to_binary(value, [:compact, decimals: 2])
    "R$ #{formatted_value}"
  end

  def format_amount(nil), do: "0,00"

  def format_amount(value, cripto \\ false) when is_float(value) or is_integer(value) do
    if cripto do
      :erlang.float_to_binary(value, [:compact, decimals: 8])
    else
      :erlang.float_to_binary(value, [:compact, decimals: 2])
    end
  end
end
