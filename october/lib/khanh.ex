defmodule Khanh.DateTimeParser do
  @fields [:year, :month, :day, :hour, :minute, :second]

  def parse(date_string, format) do
    format_items = split_format(format)

    with {:ok, {_, params}} <- extract_date_params(date_string, format_items),
         {:ok, params} <- validate_hours(params) do
      dt =
        Map.merge(
          %DateTime{
            year: 0,
            month: 1,
            day: 1,
            zone_abbr: "UTC",
            hour: 0,
            minute: 0,
            second: 0,
            microsecond: {0, 0},
            utc_offset: 0,
            std_offset: 0,
            time_zone: "Etc/UTC"
          },
          Map.take(params, @fields)
        )
        |> DateTime.add(params[:offset] || 0)

      {:ok, dt}
    else
      _err ->
        {:error, "error"}
    end
  end

  @annotations ~W(H I m S d M y Y z P p)

  defp split_format(format) do
    {items, merged_item, _} =
      format
      |> String.graphemes()
      |> Enum.reduce({[], "", false}, fn
        "%", {items, merged_item, false} ->
          {items, merged_item, true}

        "%", {items, merged_item, true} ->
          {items, merged_item <> "%", true}

        character, {items, merged_item, true} when character in @annotations ->
          items = if merged_item == "", do: items, else: [merged_item | items]
          item = "%" <> character
          {[item | items], "", false}

        character, {items, merged_item, _} ->
          {items, merged_item <> character, false}
      end)

    items = if String.length(merged_item) > 0, do: [merged_item | items], else: items
    Enum.reverse(items)
  end

  defp extract_date_params(date_string, format_items) do
    Enum.reduce_while(format_items, {:ok, {date_string, %{}}}, fn
      format_item, {:ok, {remaining_string, params}} ->
        {:cont, validate_item(format_item, remaining_string, params)}

      _, acc ->
        {:halt, acc}
    end)
  end

  defp validate_item("%H", date_string, params),
    do: validate(date_string, params, :hour, range: 0..23)

  defp validate_item("%I", date_string, params),
    do: validate(date_string, params, :hour, range: 1..12)

  defp validate_item("%m", date_string, params),
    do: validate(date_string, params, :minute, range: 0..59)

  defp validate_item("%S", date_string, params),
    do: validate(date_string, params, :second, range: 0..59)

  defp validate_item("%d", date_string, params),
    do: validate(date_string, params, :day, range: 1..31)

  defp validate_item("%M", date_string, params),
    do: validate(date_string, params, :month, range: 1..12)

  defp validate_item("%y", date_string, params),
    do: validate("20" <> date_string, params, :year, length: 4, range: 2000..2099)

  defp validate_item("%Y", date_string, params),
    do: validate(date_string, params, :year, length: 4)

  defp validate_item("%z", date_string, params) do
    with false <- Map.has_key?(params, :offset),
         false <- String.length(date_string) < 5,
         {value, remaining_string} <- String.split_at(date_string, 5),
         {sign, time_value} <- String.split_at(value, 1),
         true <- sign in ["+", "-"],
         {hour, minute} <- String.split_at(time_value, 2),
         {:ok, hour} <- parse_value(hour, :integer),
         {:ok, minute} <- parse_value(minute, :integer) do
      sign_value = if sign == "-", do: 1, else: -1
      offset = sign_value * (hour * 3600 + minute * 60)
      {:ok, {remaining_string, Map.put(params, :offset, offset)}}
    else
      _ ->
        :error
    end
  end

  defp validate_item("%P", date_string, params),
    do: validate(date_string, params, :period, type: :string, range: ["AM", "PM"])

  defp validate_item("%p", date_string, params),
    do: validate(date_string, params, :period, type: :string, range: ["am", "pm"])

  defp validate_item(item, date_string, params) do
    length_item = String.length(item)

    with false <- String.length(date_string) < length_item,
         {value, remaining_string} <- String.split_at(date_string, length_item),
         true <- value == item do
      {:ok, {remaining_string, params}}
    else
      _ -> :error
    end
  end

  defp validate(date_string, params, key, opts) do
    value_length = opts[:length] || 2
    value_type = opts[:type] || :integer
    value_range = opts[:range] || nil

    with false <- Map.has_key?(params, key),
         false <- String.length(date_string) < value_length,
         {value, remaining_string} <- String.split_at(date_string, value_length),
         {:ok, value} <- parse_value(value, value_type),
         true <- value_range == nil or value in value_range do
      {:ok, {remaining_string, Map.put(params, key, value)}}
    else
      _ ->
        :error
    end
  end

  defp parse_value(value, :integer) do
    Integer.parse(value)
    |> case do
      {value, ""} ->
        {:ok, value}

      _ ->
        :error
    end
  end

  defp parse_value(value, _), do: {:ok, value}

  defp validate_hours(params) do
    period = params[:period]
    hour = params[:hour]

    cond do
      is_nil(period) ->
        {:ok, params}

      is_nil(hour) ->
        :error

      hour not in 1..12 ->
        :error

      period in ["AM", "am"] ->
        {:ok, Map.put(params, :hour, rem(hour, 12))}

      true ->
        {:ok, Map.put(params, :hour, rem(hour, 12) + 12)}
    end
  end
end
