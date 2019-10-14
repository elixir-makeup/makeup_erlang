defmodule MakeupErlang.Mixfile do
  use Mix.Project

  @version "0.1.0"
  @repo_url "https://github.com/tmbb/makeup_erlang"

  def project do
    [
      app: :makeup_erlang,
      version: @version,
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Makeup Erlang",
      source: @repo_url,
      homepage_url: @repo_url,
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
      links: %{"GitHub" => @repo_url}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Makeup.Lexers.ErlangLexer.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:makeup, "~> 1.0"},
      {:assert_value, "~> 0.9", only: [:dev, :test]},
      {:ex_doc, "~> 0.21.1", only: [:dev, :test]}
    ]
  end
end
