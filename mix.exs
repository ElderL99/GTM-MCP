defmodule GtmMcp.MixProject do
  use Mix.Project

  def project do
    [
      app: :gtm_mcp,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GtmMcp.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:anubis_mcp, "~> 2.1"},
      {:bandit, "~> 1.5"},
      {:goth, "~> 1.4"},
      {:req, "~> 0.5"}
    ]
  end
end
