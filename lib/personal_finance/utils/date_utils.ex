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
    |> Calendar.strftime("%d/%m/%Y %H:%M")
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
end
