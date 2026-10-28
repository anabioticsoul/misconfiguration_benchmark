defmodule Cb162Probe do
  def run do
    opts = Application.fetch_env!(:cb162, :repo)

    case Postgrex.start_link(opts) do
      {:ok, pid} ->
        Process.unlink(pid)

        result =
          try do
            Postgrex.query(pid, "SELECT 1", [])
          rescue
            exception -> {:error, exception}
          end

        case result do
          {:ok, _result} ->
            IO.puts("Postgrex SSL connection succeeded")

          {:error, reason} ->
            fail(reason)
        end

      {:error, reason} ->
        fail(reason)
    end
  end

  defp fail(reason) do
    IO.puts(:stderr, "Postgrex SSL connect failed: #{inspect(reason)}")
    System.halt(1)
  end
end
