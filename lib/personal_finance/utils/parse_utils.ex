defmodule PersonalFinance.Utils.ParseUtils do
  def parse_float(val) when is_float(val), do: val
  def parse_float(val) when is_integer(val), do: val * 1.0
  def parse_float(%Decimal{} = val), do: Decimal.to_float(val)

  def parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {number, _} -> number
      :error -> 0.0
    end
  end

  def parse_float(_), do: 0.0

  def parse_int(nil), do: 0
  def parse_int(val) when is_integer(val), do: val
  def parse_int(val) when is_float(val), do: trunc(val)

  def parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {number, _} -> number
      :error -> 0
    end
  end

  def parse_int(_), do: 0

  def parse_id(""), do: nil
  def parse_id(nil), do: nil

  def parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {number, _} -> number
      :error -> nil
    end
  end

  def parse_id(id) when is_integer(id), do: id
  def parse_id(_), do: nil

  def parse_text(""), do: nil
  def parse_text(nil), do: nil

  def parse_text(text) when is_binary(text) do
    String.trim(text)
  end

  def parse_text(atom) when is_atom(atom) do
    atom
  end

  def format_float_for_input(float_val) when is_float(float_val) do
    :erlang.float_to_binary(float_val, [:compact, {:decimals, 8}])
    |> IO.iodata_to_binary()
    |> String.trim_trailing(".0")
  end

  def format_float_for_input(int_val) when is_integer(int_val) do
    to_string(int_val)
  end

  def format_float_for_input(other), do: other

  def parse_date(date) when is_binary(date) do
    [day, month, year] = String.split(date, "/")
    Date.from_iso8601!("#{year}-#{month}-#{day}")
  end

  def parse_date(%Date{} = date), do: date
  def parse_date(value), do: raise(ArgumentError, "Invalid date format: #{inspect(value)}")

  def parse_datetime(nil), do: nil
  def parse_datetime(""), do: nil

  def parse_datetime(date) when is_binary(date) do
    cond do
      String.match?(date, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        {:ok, date} = Date.from_iso8601(date)
        DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

      String.match?(date, ~r/^\d{2}[-\/]\d{2}[-\/]\d{4}$/) ->
        [day, month, year] = String.split(date, ~r/[-\/]/)
        {:ok, date} = Date.from_iso8601("#{year}-#{month}-#{day}")
        DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

      true ->
        raise ArgumentError, "Invalid datetime format: #{inspect(date)}"
    end
  end

  def parse_datetime(%DateTime{} = datetime), do: datetime
end
