defmodule Codicil.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Codicil.RateLimiter
  alias Codicil.Db.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    {:ok, pid} = start_supervised({RateLimiter, delay_ms: 10})
    %{rate_limiter: pid}
  end

  describe "enqueue/2" do
    test "returns :ok immediately", %{rate_limiter: pid} do
      function = %{id: 1, name: "test", module: "Test", docs: "Test function"}
      assert :ok = RateLimiter.enqueue(pid, function)
    end

    test "processes function asynchronously" do
      # This test verifies that processing happens in background
      # We'll need to add a way to verify processing completed
      # For now, just verify enqueue doesn't block
      function = %{id: 1, name: "test", module: "Test", docs: "Test function"}
      start_time = System.monotonic_time(:millisecond)
      :ok = RateLimiter.enqueue(function)
      end_time = System.monotonic_time(:millisecond)

      # Enqueue should return immediately (< 5ms)
      assert end_time - start_time < 5
    end
  end
end
