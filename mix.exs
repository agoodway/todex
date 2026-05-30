defmodule Todex.MixProject do
  use Mix.Project

  def project do
    [
      app: :todex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [mod: {Todex.Application, []}, extra_applications: [:logger, :runtime_tools]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:francis, "~> 0.2"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:joken, "~> 2.6"},
      {:open_api_spex, "~> 3.21"}
    ]
  end
end
