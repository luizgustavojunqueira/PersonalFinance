defmodule PersonalFinance.Utils.CurrencyUtils do
  def format_money(nil), do: "R$ 0,00"
  def format_money(%Decimal{} = d), do: d |> Decimal.to_float() |> format_money()

  def format_money(value) when is_number(value) do
    float_value = value * 1.0
    formatted_value = :erlang.float_to_binary(float_value, decimals: 2)

    [integer_part, decimal_part] =
      case String.split(formatted_value, ".") do
        [int, dec] -> [int, dec]
        [int] -> [int, "00"]
      end

    integer_part_br = String.replace(integer_part, ~r/(?<=\d)(?=(\d{3})+(?!\d))/, ".")
    "R$ #{integer_part_br},#{decimal_part}"
  end

  def format_amount(nil), do: "R$ 0,00"

  def format_amount(value, cripto \\ false) when is_float(value) or is_integer(value) do
    if cripto do
      :erlang.float_to_binary(value, [:compact, decimals: 8])
    else
      :erlang.float_to_binary(value, [:compact, decimals: 2])
    end
  end

  def format_rate(nil), do: "-"

  def format_rate(%Decimal{} = d) do
    d
    |> Decimal.mult(100)
    |> Decimal.round(2)
    |> Decimal.div(100)
    |> Decimal.to_string(:normal)
    |> then(&(&1 <> "%"))
  end

  def format_rate(v) when is_number(v) do
    v
    |> Decimal.new()
    |> format_rate()
  end

  def format_percentage(nil), do: "-"
  def format_percentage(%Decimal{} = d), do: d |> Decimal.to_float() |> format_percentage()

  def format_percentage(value) when is_number(value) do
    value
    |> Float.round(2)
    |> :erlang.float_to_binary(decimals: 2)
    |> Kernel.<>("%")
  end

  def format_percentage(_), do: "-"
end
