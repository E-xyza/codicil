# Test module with 'use Protoss' outside the module definition
# This tests that compile-time dependencies declared outside module scope
# are correctly tracked by the tracer

use Protoss

defmodule ProtossOutsideModule do
  def test_function do
    :ok
  end
end
