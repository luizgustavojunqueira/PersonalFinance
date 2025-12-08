defmodule PersonalFinance.Utils.DateUtils do
  @local_offset_hours -4

  def count_days_until(date) do
    today = Date.utc_today()
    Date.diff(date, today)
  end

  def format_date(nil), do: "Data não disponível"
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")

  def format_date(%NaiveDateTime{} = dt) do
    dt
    |> to_local_time()
    |> Calendar.strftime("%d/%m/%Y")
  end

  def format_date(%NaiveDateTime{} = dt, :with_time) do
    dt
    |> to_local_time()
    |> Calendar.strftime("%d/%m/%Y - %H:%M")
  end

  def format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y")
  def format_date(_), do: "Data inválida"

  def format_date(%DateTime{} = dt, :with_time) do
    dt
    |> to_local_time()
    |> Calendar.strftime("%d/%m/%Y - %H:%M")
  end

  defp to_local_time(%NaiveDateTime{} = dt) do
    NaiveDateTime.add(dt, @local_offset_hours * 3600, :second)
  end

  defp to_local_time(%DateTime{} = dt) do
    dt
    |> DateTime.add(@local_offset_hours * 3600, :second)
    |> DateTime.to_naive()
  end

  @doc """
  Converte um DateTime UTC para horário local (UTC-4) considerando mudança de dia.
  Retorna um NaiveDateTime no horário local.
  """
  def to_local_time_with_date(%DateTime{} = dt) do
    local_dt =
      dt
      |> DateTime.add(@local_offset_hours * 3600, :second)
      |> DateTime.to_naive()

    local_dt
  end

  @doc """
  Converte uma Date para DateTime no início do dia (00:00:00) em UTC
  """
  def to_date_time(%Date{} = date) do
    DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  end

  @doc """
  Converte uma Date para DateTime no final do dia (23:59:59.999999) em UTC
  """
  def to_end_of_day_datetime(%Date{} = date) do
    DateTime.new!(date, ~T[23:59:59.999999], "Etc/UTC")
  end

  def local_time_to_utc_with_date(%Time{} = local_time, %Date{} = date) do
    utc_offset_seconds = abs(@local_offset_hours) * 3600
    {total_seconds, _microseconds} = Time.to_seconds_after_midnight(local_time)
    utc_seconds = total_seconds + utc_offset_seconds

    case utc_seconds >= 24 * 3600 do
      true ->
        adjusted_seconds = rem(utc_seconds, 24 * 3600)
        utc_time = Time.from_seconds_after_midnight(adjusted_seconds)
        next_date = Date.add(date, 1)
        {utc_time, next_date}

      false ->
        utc_time = Time.from_seconds_after_midnight(utc_seconds)
        {utc_time, date}
    end
  end

  @doc """
  Converte DateTime em UTC para Time e Date no horário local (UTC-4), considerando mudança de dia, retornando uma tupla {Date, Time}.
  """
  def utc_datetime_to_local_date_time(%DateTime{} = dt) do
    local_dt = to_local_time_with_date(dt)
    {NaiveDateTime.to_date(local_dt), NaiveDateTime.to_time(local_dt)}
  end

  def shift_month(year, month, delta) when is_integer(year) and is_integer(month) and is_integer(delta) do
    total = year * 12 + month - 1 + delta
    new_year = div(total, 12)
    new_month = rem(total, 12) + 1
    {new_year, new_month}
  end
end
