defmodule PersonalFinance.Utils.DateUtils do
  def count_days_until(date) do
    today = Date.utc_today()
    Date.diff(date, today)
  end

  def format_date(nil), do: "Data não disponível"
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")
  def format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  def format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y")
  def format_date(_), do: "Data inválida"
  def format_date(%DateTime{} = dt, :with_time), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")
end
