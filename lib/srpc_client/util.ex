defmodule SrpcClient.Util do
  def post(%{:proxy => proxy} = conn, body), do: post(conn, body, proxy: proxy)
  def post(conn, body), do: post(conn, body, [])

  def post(conn, body, opts) do
    case HTTPoison.post(conn[:url], body, [], opts) do
      {:ok, %{:body => body, :status_code => 200}} ->
        {:ok, body}

      {:ok, %{:status_code => status_code}} ->
        {:invalid, status_code}

      error ->
        error
    end
  end

  def tag({:error, reason}, msg) do
    <<msg::binary, " error: ", reason::binary>>
  end

  def tag({:invalid, reason}, msg) do
    <<msg::binary, " invalid: ", reason::binary>>
  end
end
