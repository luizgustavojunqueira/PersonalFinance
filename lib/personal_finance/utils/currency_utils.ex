defmodule PersonalFinance.Utils.CurrencyUtils do
  def format_money(nil), do: "R$ 0,00"

  def format_money(value) when is_float(value) or is_integer(value) do
    formatted_value = :erlang.float_to_binary(value, decimals: 2)

    parts = String.split(formatted_value, ".")

    integer_part =
      parts
      |> List.first()
      |> String.replace(~r/(?<=\d)(?=(\d{3})+(?!\d))/, ",")

    decimal_part = if length(parts) > 1, do: "." <> List.last(parts), else: ".00"
    "#{integer_part}#{decimal_part}"

    "R$ #{integer_part}#{decimal_part}"
  end

  def format_amount(nil), do: "R$ 0,00"

  def format_amount(value, cripto \\ false) when is_float(value) or is_integer(value) do
    if cripto do
      :erlang.float_to_binary(value, [:compact, decimals: 8])
    else
      :erlang.float_to_binary(value, [:compact, decimals: 2])
    end
  end
end
