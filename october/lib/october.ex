defmodule October do
  @modules [Khanh.DateTimeParser, Quang.DateTimeParser, Dung.DateTimeParser]

  def run() do
    cases = prepare_cases()

    Enum.map(@modules, &run_static_test/1)
    Enum.map(@modules, &run_dynamic_test(&1, cases))
    run_benchmark(@modules, cases)
    nil
  end

  def prepare_cases do
    Enum.map(1..20, fn _ ->
      dt = random_datetime()
      format = random_format()

      fmt =
        format
        |> String.replace("M", "m", global: false)
        |> String.replace("m", "M", global: false)

      {Calendar.strftime(dt, format), fmt, dt}
    end)
  end

  def random_format() do
    [
      Enum.random(~w(y Y)),
      "m",
      "d",
      Enum.random(~w(H)),
      "S",
      "M",
      "z"
    ]
    |> Enum.map(&"%#{&1}")
    |> Enum.join(Enum.random(~w(T x : - /')))
  end

  def random_datetime() do
    NaiveDateTime.new!(
      Enum.random(2000..2099),
      Enum.random(1..12),
      Enum.random(1..30),
      Enum.random(0..23),
      Enum.random(0..59),
      Enum.random(0..59)
    )
    |> DateTime.from_naive!("Etc/UTC")
  end

  def run_static_test(module) do
    cases = [
      {"2021-10-12", "%Y-%M-%d", ~U[2021-10-12 00:00:00Z]},
      {"02/10/2021", "%d/%M/%Y", ~U[2021-10-02 00:00:00Z]},
      {"10:07:22", "%H:%m:%S", ~U[0000-01-01 10:07:22Z]},
      {"10:15:10PM", "%I:%m:%S%P", ~U[0000-01-01 22:15:10Z]},
      {"10:15:10AM", "%I:%m:%S%P", ~U[0000-01-01 10:15:10Z]},
      {"12:15:10PM", "%I:%m:%S%P", ~U[0000-01-01 12:15:10Z]},
      {"22/12/21 11:00:55", "%d/%M/%y %H:%m:%S", ~U[2021-12-22 11:00:55Z]},
      {"22-10-2021 11:67:25", "%d-%M-%Y %H:%m:%S", :error},
      {"10/15/2022 09:12:11 +0700", "%M/%d/%Y %H:%m:%S %z", ~U[2022-10-15 02:12:11Z]},
      {"10/15/2022 09:12:11 -0230", "%M/%d/%Y %H:%m:%S %z", ~U[2022-10-15 11:42:11Z]}
    ]

    {success, _error} =
      Enum.reduce(cases, {0, 0}, fn {str, format, result}, {success, error} ->
        {status, dt} = module.parse(str, format)

        cond do
          status == :error and result == :error ->
            {success + 1, error}

          status == :ok and result == dt ->
            {success + 1, error}

          true ->
            {success, error + 1}
        end
      end)

    IO.puts("Predefined test #{module} passed: #{success}/#{length(cases)}")
  end

  def run_dynamic_test(module, cases) do
    {success, _error} =
      Enum.reduce(cases, {0, 0}, fn {str, format, result} = cs, {success, error} ->
        {status, dt} = module.parse(str, format)

        cond do
          status == :error and result == :error ->
            {success + 1, error}

          status == :ok and result == dt ->
            {success + 1, error}

          true ->
            IO.inspect(cs)
            {success, error + 1}
        end
      end)

    IO.puts("Dynamic test #{module} passed: #{success}/#{length(cases)}")
  end

  def run_benchmark(modules, cases) do
    bench_func =
      Enum.map(modules, fn module ->
        {module, fn -> run_parser(module, cases) end}
      end)
      |> Enum.into(%{})

    Benchee.run(
      bench_func,
      time: 10
    )
  end

  def run_parser(module, cases) do
    Enum.each(cases, fn {str, format, _result} ->
      module.parse(str, format)
    end)
  end
end
