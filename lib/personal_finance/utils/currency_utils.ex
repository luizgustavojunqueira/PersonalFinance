defmodule PersonalFinance.Utils.CurrencyUtils do
  def format_money(nil), do: "R$ 0,00"
  def format_money(%Decimal{} = d), do: d |> Decimal.to_float() |> format_money()

  def format_money(value) when is_number(value) do
    float_value = value * 1.0
    formatted_value = :erlang.float_to_binary(float_value, decimals: 2)

    parts = String.split(formatted_value, ".")

    integer_part =
      parts
      |> List.first()
      |> String.replace(~r/(?<=\d)(?=(\d{3})+(?!\d))/, ",")

    decimal_part = if length(parts) > 1, do: "." <> List.last(parts), else: ".00"

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
end
