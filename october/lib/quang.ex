defmodule Quang.DateTimeParser do
  def parse(date_string, format_string) do
    default =
      DateTime.now!("Etc/UTC")
      |> Map.merge(%{
        year: 0,
        month: 1,
        day: 1,
        hour: 0,
        minute: 0,
        second: 0
      })
      |> DateTime.truncate(:second)

    %{pattern: pattern, groups: groups} = extract_format(format_string)

    with :ok <- validate_groups(groups),
         {:ok, group_values} <- extract_data(date_string, pattern),
         date_map <- Enum.zip(groups, group_values) |> Enum.into(%{}),
         dt <- build_datetime(date_map, default),
         _ <- DateTime.to_unix(dt) do
      {:ok, dt}
    else
      _ ->
        {:error, nil}
    end
  end

  @spec extract_data(String.t(), String.t()) :: {:ok, list()} | {:error, String.t()}
  defp extract_data(date_string, pattern) do
    with {_, {:ok, regex}} <- {:compile, Regex.compile(pattern)},
         {_, [_ | group_values]} <- {:validate, Regex.run(regex, date_string)} do
      {:ok, group_values}
    else
      {:compile, {:error, error}} ->
        {:error, "#{inspect(error)}"}

      _error ->
        {:error, "Invalid format"}
    end
  end

  # Extract given format
  # Input: "%d/%M/%Y"
  # Output:
  # %{
  #    pattern: "(\d\d)/(\d\d)/(\d\d\d\d)",
  #    groups: [:day, :month, :year]
  # }
  @spec extract_format(String.t()) :: map()
  def extract_format(format) do
    structure =
      %{pattern: "", groups: [], format: String.graphemes(format)}
      |> do_extract()
      |> Map.drop([:format])

    Map.put(structure, :pattern, "^" <> structure.pattern <> "$")
  end

  defp validate_groups(groups) do
    with unique_groups <- Enum.dedup(groups),
         true <- unique_groups == groups do
      :ok
    else
      _ ->
        {:error, "Invalid format"}
    end
  end

  defp do_extract(params) do
    with [prefix, type | remains] <- params.format do
      case map_type("#{prefix}#{type}") do
        %{pattern: pattern, groups: groups} ->
          params
          |> Map.put(:pattern, params.pattern <> pattern)
          |> Map.put(:groups, params.groups ++ groups)
          |> Map.put(:format, remains)
          |> do_extract()

        _ ->
          params
          |> Map.put(:pattern, params.pattern <> prefix)
          |> Map.put(:format, [type | remains])
          |> do_extract()
      end
    else
      _ ->
        Map.put(
          params,
          :pattern,
          params.pattern <> Enum.reduce(params.format, "", &(&2 <> "#{&1}"))
        )
    end
  end

  defp map_type(type) do
    case type do
      "%d" ->
        %{
          pattern: ~S"(0[1-9]|[1-2][0-9]|3[0-1])",
          groups: [:day]
        }

      "%M" ->
        %{
          pattern: ~S"(0[1-9]|1[0-2])",
          groups: [:month]
        }

      "%Y" ->
        %{
          pattern: ~S"(\d\d\d\d)",
          groups: [:year]
        }

      "%H" ->
        %{
          pattern: ~S"([0-1][0-9]|2[0-3])",
          groups: [:hour]
        }

      "%m" ->
        %{
          pattern: ~S"([0-5][0-9])",
          groups: [:minute]
        }

      "%S" ->
        %{
          pattern: ~S"([0-5][0-9])",
          groups: [:second]
        }

      "%I" ->
        %{
          pattern: ~S"(0[0-9]|1[0-2])",
          groups: [:hour]
        }

      "%P" ->
        %{
          pattern: ~S"([A|P]M)",
          groups: [:post]
        }

      "%p" ->
        %{
          pattern: ~S"([a|p]m)",
          groups: [:post]
        }

      "%y" ->
        %{
          pattern: ~S"(\d\d)",
          groups: [:year_2_digits]
        }

      "%z" ->
        %{
          pattern: ~S"([+|-]\d{4})",
          groups: [:timezone]
        }

      _ ->
        :error
    end
  end

  @date_time_fields [
    :day,
    :month,
    :year,
    :hour,
    :minute,
    :second,
    :post,
    :year_2_digits,
    :timezone
  ]
  defp build_datetime(datetime_map, dt) do
    Enum.reduce(@date_time_fields, dt, fn field, acc ->
      if value = datetime_map[field] do
        set_date_field(field, value, acc)
      else
        acc
      end
    end)
  end

  defp set_date_field(:day, value, dt) do
    Map.put(dt, :day, String.to_integer(value))
  end

  defp set_date_field(:month, value, dt) do
    Map.put(dt, :month, String.to_integer(value))
  end

  defp set_date_field(:year, value, dt) do
    Map.put(dt, :year, String.to_integer(value))
  end

  defp set_date_field(:hour, value, dt) do
    Map.put(dt, :hour, String.to_integer(value))
  end

  defp set_date_field(:minute, value, dt) do
    Map.put(dt, :minute, String.to_integer(value))
  end

  defp set_date_field(:second, value, dt) do
    Map.put(dt, :second, String.to_integer(value))
  end

  defp set_date_field(:post, value, dt) do
    if Map.get(dt, :hour) < 12 and value in ["PM", "pm"] do
      DateTime.add(dt, 12 * 3600, :second)
    else
      dt
    end
  end

  defp set_date_field(:year_2_digits, value, dt) do
    year = Map.get(DateTime.now!("Etc/UTC"), :year)
    Map.put(dt, :year, year - rem(year, 100) + String.to_integer(value))
  end

  defp set_date_field(:timezone, value, dt) do
    {hour_offset, minute_offset} =
      case value do
        "+" <> offset_str ->
          [[hour_str], [minute_str]] = Regex.scan(~r/../, offset_str)
          {-1 * String.to_integer(hour_str), -1 * String.to_integer(minute_str)}

        "-" <> offset_str ->
          [[hour_str], [minute_str]] = Regex.scan(~r/../, offset_str)
          {String.to_integer(hour_str), String.to_integer(minute_str)}

        _ ->
          {0, 0}
      end

    dt
    |> DateTime.add(hour_offset * 3600, :second)
    |> DateTime.add(minute_offset * 60, :second)
  end

  defp set_date_field(_, _value, dt), do: dt
end
