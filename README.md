# october-contest

Viết 1 module với 1 public function `parse` để parse chuỗi thời gian về struct `DateTime` hỗ trợ một số selector cơ bản của `strptime`

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
  | P | PM or AM | |
  | p | pm or am | |

### Ví dụ:

```elixir
TimeParser.parse("10/12/2021 10:15:00AM +0700", "%d/%M/%Y %I:%m:S%P %z")
# > ~U[2021-12-10 03:15:00]
````

### Template
```elxir
defmodule DateTimeParser do
  def parse(date_string, format) do
    # your code
  end
end
```

### Benchmark
Sử dụng benchee để benchmak

https://github.com/bencheeorg/benchee

### Cách đánh giá kế quả
- Sẽ có 1 bộ test public (sẽ thêm sau)
- Và 1 bộ test secret

Kết quả dành cho solution nào pass tất cả test và có thời gian chạy nhanh nhất ( tính trung bình cho 10000 round)

### Sample test

```elixir
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
  {"10/15/2022 09:12:11 -0230", "%M/%d/%Y %H:%m:%S %z", ~U[2022-10-15 11:42:11Z]},
]

{success, _error} =
Enum.reduce(cases, {0, 0}, fn {str, format, result}, {success, error} ->
  {status, dt} = DateTimeParser.parse(str, format)

  cond  do
    status == :error and result == :error ->
      {success + 1, error}
    status == :ok and result == dt ->
      {success + 1, error}
    true ->
      {success, error + 1}
  end
end)

IO.puts("Test passed: #{success}/#{length(cases)}")
```
