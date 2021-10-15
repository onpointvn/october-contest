defmodule Dung.DateTimeParser do
  @moduledoc """
  Provide some missing function for buildin datetimte and naive datetime
  """

  @doc """
  Get DateTime.utc_now and truncate
  Default truncate by `:second`
  """
  def naive_now(unit \\ :second) do
    DateTime.utc_now()
    |> DateTime.truncate(unit)
  end

  @doc """
  Convert DateTime to unix timestamps
  """
  def naive_to_unix(nil), do: nil

  def naive_to_unix(naive) do
    naive
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end

  @doc """
  Truncate datetime by second
  """
  def truncate(dt) do
    DateTime.truncate(dt, :second)
  end

  @doc """
  Convert to second
  """
  def to_second(value, unit) when is_integer(value) do
    case unit do
      :minute -> value * 60
      :hour -> value * 3600
      :day -> value * 86_400
      :week -> value * 604_800
      _ -> raise "invalid unit"
    end
  end

  def minute(value), do: to_second(value, :minute)
  def hour(value), do: to_second(value, :hour)
  def day(value), do: to_second(value, :day)

  @doc """
  Add amount of time to given datetime

  - `opts` is list of {unit, value} to add
  Avalable units are: `:minute | :hour | :day | :week`

  **Example**
  Adding 1 day and 10 hour to givent datetime

      #> add(dt, day: 1, hour: 10)
  """
  def add(dt, opts \\ [])

  def add(%DateTime{} = dt, opts) do
    Enum.reduce(opts, dt, fn {unit, value}, acc ->
      DateTime.add(acc, to_second(value, unit))
    end)
  end

  @mapping %{
    "H" => "(?<hour>\\d{2})",
    "I" => "(?<hour12>\\d{2})",
    "m" => "(?<minute>\\d{2})",
    "S" => "(?<second>\\d{2})",
    "d" => "(?<day>\\d{2})",
    "M" => "(?<month>\\d{2})",
    "y" => "(?<year2>\\d{2})",
    "Y" => "(?<year>-?\\d{4})",
    "z" => "(?<tz>[+-]?\\d{4})",
    "Z" => "(?<tz_name>[a-zA-Z_\/]+)",
    "P" => "(?<P>PM|AM)",
    "p" => "(?<p>pm|am)",
    "%" => "%"
  }

  @doc """
  Parse string to datetime struct

  **Example**

      parse("2021-20-10", "%Y-%M-%d")

  Support format
  | format | description| value example |
  | -- | -- | -- |
  | H | 24 hour | 00 - 23 |
  | I | 12 hour | 00 - 12 |
  | m | minute| 00 - 59 |
  | S | second | 00 - 59 |
  | d | day | 01 - 31 |
  | M | month | 01 -12 |
  | y | 2 digits year | 00 - 99 |
  | Y | 4 digits year | |
  | z | timezone offset | +0100, -0330 |
  | Z | timezone name | UTC+7, Asia/Ho_Chi_Minh |
  | P | PM or AM | |
  | p | pm or am | |
  """

  def from_iso8601!(dt_string) do
    case DateTime.from_iso8601(dt_string) do
      {:ok, dt} -> dt
      {:error, _} -> raise ArgumentError, "Invalid ISO8061 date time string"
    end
  end

  def parse!(dt_string, format) do
    case parse(dt_string, format) do
      {:ok, dt} -> dt
      {:error, message} -> raise "Parse string #{dt_string} with error: #{message}"
    end
  end

  def parse(dt_string, format) do
    format
    |> build_regex
    |> Regex.named_captures(dt_string)
    |> cast_data
    |> to_datetime
  end

  def build_regex(format) do
    keys = Map.keys(@mapping) |> Enum.join("")

    Regex.compile!("([^%]*)%([#{keys}])([^%]*)")
    |> Regex.scan(format)
    |> Enum.map(fn [_, s1, key, s2] ->
      [s1, Map.get(@mapping, key), s2]
    end)
    |> to_string()
    |> Regex.compile!()
  end

  @default_value %{
    day: 1,
    month: 1,
    year: 0,
    hour: 0,
    minute: 0,
    second: 0,
    utc_offset: 0,
    tz_name: "UTC",
    shift: "AM"
  }
  def cast_data(nil), do: {:error, "invalid datetime"}

  def cast_data(captures) do
    captures
    |> Enum.reduce_while([], fn {part, value}, acc ->
      case cast(part, value) do
        {:ok, data} -> {:cont, [data | acc]}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:error, _} = error -> error
      data -> Enum.into(data, @default_value)
    end
  end

  @value_rages %{
    "hour" => [0, 23],
    "hour12" => [0, 12],
    "minute" => [0, 59],
    "second" => [0, 59],
    "day" => [0, 31],
    "month" => [1, 12],
    "year2" => [0, 99],
    "offset_h" => [-12, +14],
    "offset_m" => [0, 59]
  }

  defp cast("p", value) do
    cast("P", String.upcase(value))
  end

  defp cast("P", value) do
    {:ok, {:shift, value}}
  end

  defp cast("tz", value) do
    {hour, minute} = String.split_at(value, 3)

    with {:ok, {_, hour}} <- cast("offset_h", hour),
         {:ok, {_, minute}} <- cast("offset_m", minute) do
      sign =
        if hour < 0 do
          -1
        else
          1
        end

      {:ok, {:utc_offset, sign * (abs(hour) * 3600 + minute * 60)}}
    else
      _ -> {:error, "#{value} is invalid timezone offset"}
    end
  end

  defp cast("tz_name", value) do
    {:ok, {:tz_name, value}}
  end

  defp cast(part, value) do
    value = String.to_integer(value)

    valid =
      case Map.get(@value_rages, part) do
        [min, max] ->
          value >= min and value <= max

        _ ->
          true
      end

    if valid do
      {:ok, {String.to_atom(part), value}}
    else
      {:error, "#{value} is not a valid #{part}"}
    end
  end

  defp to_datetime({:error, _} = error), do: error

  defp to_datetime(%{year2: value} = data) do
    current_year = DateTime.utc_now() |> Map.get(:year)
    year = div(current_year, 100) * 100 + value

    data
    |> Map.put(:year, year)
    |> Map.delete(:year2)
    |> to_datetime()
  end

  defp to_datetime(%{hour12: hour} = data) do
    # 12AM is not valid

    if hour == 12 and data.shift == "AM" do
      {:error, "12AM is invalid value"}
    else
      hour =
        cond do
          hour == 12 and data.shift == "PM" -> hour
          data.shift == "AM" -> hour
          data.shift == "PM" -> hour + 12
        end

      data
      |> Map.put(:hour, hour)
      |> Map.delete(:hour12)
      |> to_datetime()
    end
  end

  defp to_datetime(data) do
    with {:ok, date} <- Date.new(data.year, data.month, data.day),
         {:ok, time} <- Time.new(data.hour, data.minute, data.second),
         {:ok, datetime} <- DateTime.new(date, time) do
      datetime = DateTime.add(datetime, -data.utc_offset, :second)

      if data.tz_name != "UTC" do
        DateTime.shift_zone(datetime, data.tz_name)
      else
        {:ok, datetime}
      end
    end
  end
end
