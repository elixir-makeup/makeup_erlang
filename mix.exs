defmodule MakeupErlang.Mixfile do
  use Mix.Project

  def project do
    [
      app: :makeup_erlang,
      version: "0.5.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Package
      package: package(),
      description: description(),
      docs: [
        main: "readme",
        extras: [
          "README.md"
        ]
      ]
    ]
  end

  defp description do
    """
    Erlang lexer for the Makeup syntax highlighter.
    """
  end

  defp package do
    [
      name: :makeup_erlang,
      licenses: ["BSD"],
      maintainers: ["Tiago Barroso <tmbb@campus.ul.pt>"],
      links: %{"GitHub" => "https://github.com/tmbb/makeup_erlang"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:makeup, "~> 0.8"},
      {:assert_value, "~> 0.9", only: [:dev, :test]},
      {:ex_doc, "~> 0.19.3", only: [:dev, :test]}
    ]
  end
end
