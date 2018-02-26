defmodule SrpcClient.Transport do
  alias SrpcClient.{Conn, Request}

  @callback srpc(conn :: Conn.t(), packet :: binary()) :: {:ok, binary()} | {:error, binary()}
  @callback app(conn :: Conn.t(), request :: Request.t()) :: {:ok, binary()} | {:error, binary()}
end
