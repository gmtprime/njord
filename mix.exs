defmodule Njord.Mixfile do
  use Mix.Project

  @version "0.1.0"

  @description """
    A wrapper over HTTPoison to build client APIs.
  """

  def project do
    [app: :njord,
     version: @version,
     elixir: "~> 1.2",
     name: "Njord",
     description: @description,
     package: package,
     deps: deps,
     source_url: "https://github.com/gmtprime/njord"]
  end

  def application do
    [applications: [:logger, :httpoison]]
  end

  defp deps do
    [{:httpoison, "~> 0.8.1"},
     {:meck, "~> 0.8.2", only: :test}]
  end

  defp package do
    [maintainers: ["Alexander de Sousa"],
     license: ["MIT"],
     links: %{"Github" => "https://github.com/gmtprime/njord"}]
  end
end
