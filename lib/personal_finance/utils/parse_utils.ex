defmodule PersonalFinance.Utils.ParseUtils do
  def parse_float(val) when is_float(val), do: val
  def parse_float(val) when is_integer(val), do: val * 1.0

  def parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {number, _} -> number
      :error -> 0.0
    end
  end

  def parse_float(_), do: 0.0

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
end
