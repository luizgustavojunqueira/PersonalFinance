defmodule PersonalFinance.Math.Loans do
  @moduledoc """
  Financing and loan helpers (Price system).
  """

  @type rate_period :: :month | :year
  @type duration_unit :: :month | :year

  @type price_params :: %{
          required(:principal) => number(),
          required(:rate) => number(),
          required(:rate_period) => rate_period(),
          required(:duration) => pos_integer(),
          required(:duration_unit) => duration_unit(),
          optional(:extra) => number()
        }

  @type schedule_row :: %{
          period: pos_integer(),
          payment: float(),
          interest: float(),
          amortization: float(),
          balance: float()
        }

  @spec price_amortization(price_params()) :: %{payment: float(), total_paid: float(), total_interest: float(), schedule: [schedule_row()], months_used: pos_integer()} | nil
  def price_amortization(params) do
    principal = to_float(params.principal)
    rate = to_float(params.rate) / 100.0
    rate_period = params.rate_period || :month
    duration = to_int(params.duration)
    duration_unit = params.duration_unit || :month
    extra = to_float(params[:extra] || 0)

    total_months =
      case {duration_unit, duration} do
        {:year, d} when d > 0 -> d * 12
        {:month, d} when d > 0 -> d
        _ -> 0
      end

    monthly_rate =
      case {rate_period, rate} do
        {_period, r} when r <= 0 -> 0.0
        {:month, r} -> r
        {:year, r} -> :math.pow(1.0 + r, 1.0 / 12.0) - 1.0
      end

    cond do
      principal <= 0 or monthly_rate <= 0 or total_months <= 0 ->
        nil

      true ->
        payment = price_payment(principal, monthly_rate, total_months)

        {schedule, total_interest, months_used} = build_schedule(principal, monthly_rate, total_months, payment, extra)
        total_paid = Enum.reduce(schedule, 0.0, fn row, acc -> acc + row.payment end)

        %{
          payment: payment,
          total_paid: total_paid,
          total_interest: total_interest,
          schedule: schedule,
          months_used: months_used
        }
    end
  end

  @spec sac_amortization(price_params()) :: %{payment: float(), total_paid: float(), total_interest: float(), schedule: [schedule_row()], months_used: pos_integer()} | nil
  def sac_amortization(params) do
    principal = to_float(params.principal)
    rate = to_float(params.rate) / 100.0
    rate_period = params.rate_period || :month
    duration = to_int(params.duration)
    duration_unit = params.duration_unit || :month
    extra = to_float(params[:extra] || 0)

    total_months =
      case {duration_unit, duration} do
        {:year, d} when d > 0 -> d * 12
        {:month, d} when d > 0 -> d
        _ -> 0
      end

    monthly_rate =
      case {rate_period, rate} do
        {_period, r} when r <= 0 -> 0.0
        {:month, r} -> r
        {:year, r} -> :math.pow(1.0 + r, 1.0 / 12.0) - 1.0
      end

    cond do
      principal <= 0 or monthly_rate <= 0 or total_months <= 0 ->
        nil

      true ->
        amortization = principal / total_months

        {schedule, total_interest, months_used} = build_sac_schedule(principal, monthly_rate, total_months, amortization, extra)
        payments = Enum.map(schedule, & &1.payment)
        total_paid = Enum.sum(payments)

        first_payment = List.first(payments) || 0.0

        %{
          payment: first_payment,
          total_paid: total_paid,
          total_interest: total_interest,
          schedule: schedule,
          months_used: months_used
        }
    end
  end

  defp price_payment(principal, monthly_rate, months) do
    numerator = principal * monthly_rate
    denominator = 1.0 - :math.pow(1.0 + monthly_rate, -months)

    if denominator == 0.0 do
      0.0
    else
      numerator / denominator
    end
  end

  defp build_schedule(principal, monthly_rate, months, payment, extra) do
    1..months
    |> Enum.reduce_while({[], principal, 0.0}, fn period, {rows, balance, acc_interest} ->
      if balance <= 0.0 do
        {:halt, {rows, balance, acc_interest}}
      else
        interest = balance * monthly_rate
        regular_amortization = payment - interest
        total_amortization = min(balance, regular_amortization + extra)
        new_balance = balance - total_amortization
        total_interest = acc_interest + interest

        row = %{
          period: period,
          payment: interest + total_amortization,
          interest: interest,
          amortization: total_amortization,
          balance: max(new_balance, 0.0)
        }

        if new_balance <= 0.0 do
          {:halt, {[row | rows], row.balance, total_interest}}
        else
          {:cont, {[row | rows], new_balance, total_interest}}
        end
      end
    end)
    |> then(fn {rows, _balance, total_interest} ->
      rows = Enum.reverse(rows)
      {rows, total_interest, length(rows)}
    end)
  end

  defp build_sac_schedule(principal, monthly_rate, months, amortization, extra) do
    1..months
    |> Enum.reduce_while({[], principal, 0.0}, fn period, {rows, balance, acc_interest} ->
      if balance <= 0.0 do
        {:halt, {rows, balance, acc_interest}}
      else
        interest = balance * monthly_rate
        total_amortization = min(balance, amortization + extra)
        payment = interest + total_amortization
        new_balance = balance - total_amortization
        total_interest = acc_interest + interest

        row = %{
          period: period,
          payment: payment,
          interest: interest,
          amortization: total_amortization,
          balance: max(new_balance, 0.0)
        }

        if new_balance <= 0.0 do
          {:halt, {[row | rows], row.balance, total_interest}}
        else
          {:cont, {[row | rows], new_balance, total_interest}}
        end
      end
    end)
    |> then(fn {rows, _balance, total_interest} ->
      rows = Enum.reverse(rows)
      {rows, total_interest, length(rows)}
    end)
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
