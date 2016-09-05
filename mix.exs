defmodule Njord.Mixfile do
  use Mix.Project

  @version "1.0.0"

  def project do
    [app: :njord,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     docs: docs(),
     deps: deps()]
  end

  def application do
    [applications: [:logger, :httpoison]]
  end

  defp deps do
    [{:httpoison, "~> 0.9.0"},
     {:earmark, ">= 0.0.0"},
     {:ex_doc, "~> 0.13", only: :dev},
     {:credo, "~> 0.4.8", only: [:dev, :docs]},
     {:inch_ex, ">= 0.0.0", only: [:dev, :docs]}]
  end

  defp docs do
    [source_url: "https://github.com/gmtprime/njord",
     source_ref: "v#{@version}",
     main: Njord]
  end

  defp description do
    """
    Wrapper around HTTPoison to build client REST API libraries as
    specifications.
    """
  end

  defp package do
    [maintainers: ["Alexander de Sousa"],
     licenses: ["MIT"],
     links: %{"Github" => "https://github.com/gmtprime/njord"}]
  end
end
