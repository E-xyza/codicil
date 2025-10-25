# Test module with 'use Protoss' outside the module definition
# Corner case: tracer should not crash when dependencies are declared outside module scope

use Protoss

defmodule ProtossOutsideModule do
  def test_function do
    :ok
  end
end
