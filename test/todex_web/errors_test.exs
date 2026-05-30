defmodule TodexWeb.ErrorsTest do
  use ExUnit.Case, async: true

  alias TodexWeb.Errors

  describe "error_info/2 generic fallback" do
    test "unknown reasons return the supplied default map" do
      default = %{code: "error", message: "Something went wrong", details: %{}}

      assert Errors.error_info(:totally_unknown_reason, default) == default
    end

    test "known reasons ignore the supplied default" do
      assert Errors.error_info(:not_found, %{code: "x"}) ==
               %{status: 404, code: "not_found", message: "Not found", details: %{}}
    end
  end
end
