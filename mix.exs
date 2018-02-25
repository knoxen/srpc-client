defmodule SrpcClient.Mixfile do
  use Mix.Project

  def project do
    [
      app: :srpc_client,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ] ++ project(Mix.env())
  end

  defp project(:dev) do
    [erlc_options: []]
  end

  # CxTBD The erlc_options don't seem to "take". Pass --no-debug-info to mix compile for now.
  defp project(:prod) do
    [erlc_options: [:no_debug_info, :warnings_as_errors]]
  end

  def application do
    [
      extra_applications: [],
      mod: {SrpcClient, []}
    ]
  end

  defp deps do
    [
      {:poison, "~> 3.1"}
    ] ++ deps(Mix.env())
  end

  defp deps(:dev) do
    [
      {:srpc_lib, path: "../../../erlang/srpc_lib"}
    ]
  end

  defp deps(:prod) do
    [
      {:srpc_lib, path: "local/srpc_lib", compile: false}
    ]
  end
end
