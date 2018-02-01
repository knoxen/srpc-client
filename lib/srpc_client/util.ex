defmodule SrpcClient.Util do

  def post(url, body) do
    case HTTPoison.post(url, body, [], proxy: "http://localhost.charlesproxy.com:8888") do
      {:ok, %{:body => body, :status_code => 200}} ->
        {:ok, body}

      {:ok, %{:status_code => status_code}} ->
        {:invalid, status_code}

      error ->
        error
    end
  end
end
