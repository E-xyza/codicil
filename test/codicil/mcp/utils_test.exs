defmodule Codicil.MCP.UtilsTest do
  use ExUnit.Case, async: true

  alias Codicil.MCP.Utils

  describe "truncate_lines/1" do
    test "truncates lines that are too long" do
      assert Utils.truncate_lines(String.duplicate("a", 2011)) ==
               String.duplicate("a", 2000) <> " [11 characters truncated] ..."
    end

    test "preserves lines that are not too long" do
      short_line = "This is a short line"
      assert Utils.truncate_lines(short_line) == short_line
    end

    test "handles multiple lines with mixed lengths" do
      input = "short\n#{String.duplicate("x", 2100)}\nanother short"
      result = Utils.truncate_lines(input)

      lines = String.split(result, "\n")
      assert Enum.at(lines, 0) == "short"
      assert Enum.at(lines, 1) == String.duplicate("x", 2000) <> " [100 characters truncated] ..."
      assert Enum.at(lines, 2) == "another short"
    end

    test "handles empty strings" do
      assert Utils.truncate_lines("") == ""
    end
  end

  describe "detect_file_line_endings/1" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      lf_file = Path.join(tmp_dir, "lf.txt")
      crlf_file = Path.join(tmp_dir, "crlf.txt")
      mixed_file = Path.join(tmp_dir, "mixed.txt")

      File.write!(lf_file, "Hello\nWorld\n")
      File.write!(crlf_file, "Hello\r\nWorld\r\n")
      File.write!(mixed_file, "Hello\r\nWorld\nCool")

      {:ok, %{lf_file: lf_file, crlf_file: crlf_file, mixed_file: mixed_file}}
    end

    test "returns :lf if the file uses LF line endings", %{
      lf_file: lf_file,
      crlf_file: crlf_file,
      mixed_file: mixed_file
    } do
      assert :lf = Utils.detect_file_line_endings(lf_file)
      assert :crlf = Utils.detect_file_line_endings(crlf_file)
      # when equal, line feed wins
      assert :lf = Utils.detect_file_line_endings(mixed_file)
    end

    test "handles non-existent files" do
      assert Utils.detect_file_line_endings("/non/existent/file.txt") == nil
    end
  end

  describe "detect_line_endings/1" do
    test "detects LF line endings" do
      assert Utils.detect_line_endings("Hello\nWorld\n") == :lf
    end

    test "detects CRLF line endings" do
      assert Utils.detect_line_endings("Hello\r\nWorld\r\n") == :crlf
    end

    test "handles mixed line endings (LF wins when equal)" do
      assert Utils.detect_line_endings("Hello\r\nWorld\nCool") == :lf
    end

    test "defaults to LF for strings with no line endings" do
      assert Utils.detect_line_endings("no line endings here") == :lf
    end
  end
end
