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

  describe "error_info/2 sharing errors" do
    test "maps sharing domain errors to stable response metadata" do
      assert Errors.error_info(:share_already_exists) == %{
               status: 409,
               code: "share_already_exists",
               message: "Share already exists",
               details: %{}
             }

      assert Errors.error_info(:cannot_share_with_self) == %{
               status: 422,
               code: "cannot_share_with_self",
               message: "Cannot share with self",
               details: %{}
             }

      assert Errors.error_info(:forbidden) == %{
               status: 403,
               code: "forbidden",
               message: "Forbidden",
               details: %{}
             }
    end
  end
end
