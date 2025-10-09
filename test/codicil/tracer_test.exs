defmodule Codicil.TracerTest do
  use ExUnit.Case, async: true

  alias Codicil.Tracer

  describe "trace/2" do
    test "returns :ok for :on_module event" do
      bytecode = <<>>
      env = %Macro.Env{}

      assert :ok = Tracer.trace({:on_module, bytecode, []}, env)
    end

    test "returns :ok for remote_function event" do
      meta = [line: 10]
      env = %Macro.Env{}

      assert :ok = Tracer.trace({:remote_function, meta, String, :length, 1}, env)
    end

    test "returns :ok for import event" do
      meta = [line: 5]
      env = %Macro.Env{}

      assert :ok = Tracer.trace({:import, meta, Enum, []}, env)
    end

    test "returns :ok for alias event" do
      meta = [line: 3]
      env = %Macro.Env{}

      assert :ok = Tracer.trace({:alias, meta, MyApp.Module, [], []}, env)
    end

    test "returns :ok for local_function event" do
      meta = [line: 15]
      env = %Macro.Env{}

      assert :ok = Tracer.trace({:local_function, meta, :helper, 2}, env)
    end
  end
end
