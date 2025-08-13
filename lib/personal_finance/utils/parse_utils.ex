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
end
