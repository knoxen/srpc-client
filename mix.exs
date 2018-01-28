defmodule SrpcClient.Mixfile do
  use Mix.Project

  def project do
    [
      app: :srpc_client,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SrpcClient, []}
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 1.0"}
    ] ++ deps(Mix.env())
  end

  defp deps(:dev) do
    [
      {:srpc_lib, path: "../../../erlang/srpc_lib"}
    ]
  end

  defp deps(:prod) do
    [
      {:srpc_lib, path: "../../../erlang/srpc_lib"}
      # {:srpc_lib, path: "local/srpc_lib", compile: false},
    ]
  end
end
