defmodule Eden.Mixfile do
  use Mix.Project

  @source_url "https://github.com/jfacorro/Eden/"
  @version "2.1.0"

  def project do
    [
      app: :eden,
      version: @version,
      elixir: "~> 1.11",
      description: description(),
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [applications: [:timex, :elixir_array]]
  end

  defp deps do
    [
      {:elixir_array, "~> 2.1.0"},
      {:timex, "~> 3.7"},
      {:ex_doc, "~> 0.23", only: :dev},
      {:earmark, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    edn (extensible data notation) encoder/decoder implemented in Elixir.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md"],
      contributors: ["Juan Facorro"],
      licenses: ["Apache 2.0"],
      links: %{
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md",
        "GitHub" => @source_url,
        "edn format" => "https://github.com/edn-format/edn"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: @version,
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end
end
