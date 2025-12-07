defmodule PersonalFinance.Math.Debts do
  @moduledoc """
  Debt payoff vs. invest comparison helpers.
  """

  @type comparison_params :: %{
          required(:price) => number(),
          optional(:discount_pct) => number(),
          required(:installments) => pos_integer(),
          required(:finance_rate) => number(),
          required(:invest_rate) => number()
        }
  @type finance_with_invest_scenario :: %{
          payment: float(),
          total_paid: float(),
          total_interest: float(),
          final_balance: float(),
          net_position: float(),
          timeline: list()
        }

  @type finance_no_invest_scenario :: %{
          payment: float(),
          total_paid: float(),
          total_interest: float(),
          total_cost: float()
        }

  @type upfront_scenario :: %{
          upfront_cost: float(),
          discount_amount: float(),
          net_position: float()
        }

  @type result :: %{
          finance_with_invest: finance_with_invest_scenario(),
          finance_no_invest: finance_no_invest_scenario(),
          upfront: upfront_scenario(),
          winner: :finance_invest | :upfront | :tie,
          diff: float(),
          installments: pos_integer()
        }

  @spec compare(comparison_params()) :: result() | nil
  def compare(params) do
    price = to_float(params.price)
    discount_pct = max(to_float(params[:discount_pct] || 0.0), 0.0)
    installments = to_int(params.installments)
    finance_rate = to_float(params.finance_rate) / 100.0
    invest_rate = to_float(params.invest_rate) / 100.0

    if price <= 0 or installments <= 0 or finance_rate < 0 or invest_rate < 0 do
      nil
    else
      {payment, total_paid, total_interest, finance_final, finance_timeline} =
        finance_with_invest_path(price, finance_rate, installments, invest_rate)

      finance_net_cost = total_paid - finance_final

      finance_no_invest = %{
        payment: payment,
        total_paid: total_paid,
        total_interest: total_interest,
        total_cost: total_paid
      }

      discount_amount = price * (discount_pct / 100.0)
      upfront_cost = price - discount_amount
      upfront_net_cost = upfront_cost

      diff = upfront_net_cost - finance_net_cost

      winner =
        cond do
          diff > 0.0 -> :finance_invest
          diff < 0.0 -> :upfront
          true -> :tie
        end

      %{
        finance_with_invest: %{
          payment: payment,
          total_paid: total_paid,
          total_interest: total_interest,
          final_balance: finance_final,
          net_position: finance_net_cost,
          timeline: finance_timeline
        },
        finance_no_invest: finance_no_invest,
        upfront: %{
          upfront_cost: upfront_cost,
          discount_amount: discount_amount,
          net_position: upfront_net_cost
        },
        winner: winner,
        diff: diff,
        installments: installments
      }
    end
  end

  defp finance_with_invest_path(price, finance_rate, installments, invest_rate) do
    payment = finance_payment(price, finance_rate, installments)
    total_paid = payment * installments
    total_interest = total_paid - price

    {timeline, final_balance} =
      Enum.reduce(1..installments, {[], price}, fn period, {points, balance} ->
        accrued = balance * (1.0 + invest_rate)
        new_balance = accrued - payment

        point = %{
          period: period,
          balance: new_balance,
          payment: payment,
          accrued_interest: accrued - balance
        }

        {[point | points], new_balance}
      end)
      |> then(fn {points, final_balance} -> {Enum.reverse(points), final_balance} end)

    {payment, total_paid, total_interest, final_balance, timeline}
  end

  defp finance_payment(_principal, _rate, installments) when installments <= 0, do: 0.0
  defp finance_payment(principal, _rate, _installments) when principal <= 0, do: 0.0

  defp finance_payment(principal, rate, installments) when rate <= 0 do
    principal / installments
  end

  defp finance_payment(principal, rate, installments) do
    factor = :math.pow(1.0 + rate, installments)
    principal * (rate * factor) / (factor - 1.0)
  end

  defp to_float(nil), do: 0.0
  defp to_float(v) when is_integer(v), do: v * 1.0
  defp to_float(v) when is_float(v), do: v

  defp to_float(v) when is_binary(v) do
    case Float.parse(v) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp to_int(nil), do: 0
  defp to_int(v) when is_integer(v), do: v

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp to_int(v) when is_float(v), do: trunc(v)
end
