defmodule Attempt.Mixfile do
  use Mix.Project

  @version "0.1.0-dev"

  def project do
    [
      app: :attempt,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.18", only: [:dev, :docs]}
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      main: "README",
      extras: [
        "README.md",
        "LICENSE.md",
        "CHANGELOG.md"
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache 2.0"],
      links: links(),
      files: [
        "lib",
        "config",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*"
      ]
    ]
  end

  def links do
    %{
      "GitHub" => "https://github.com/kipcole9/attempt",
      "Readme" => "https://github.com/kipcole9/attempt/blob/v#{@version}/README.md",
      "Changelog" => "https://github.com/kipcole9/attempt/blob/v#{@version}/CHANGELOG.md"
    }
  end
end
