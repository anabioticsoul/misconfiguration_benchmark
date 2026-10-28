defmodule Cb162.MixProject do
  use Mix.Project

  def project do
    [
      app: :cb162,
      version: "0.1.0",
      elixir: "~> 1.12",
      config_path: "../config/config.exs",
      deps: [{:postgrex, "~> 0.19.3"}]
    ]
  end
end
