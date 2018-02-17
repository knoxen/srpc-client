defmodule SrpcClient do
  @moduledoc """
  Documentation for SrpcClient.
  """

  alias SrpcClient.{ConnectionServer, ConnectionSupervisor, Registration}

  use Application

  def start(_type, []) do
    Process.register(self(), __MODULE__)

    :ok =
      required_opt(:srpc_file)
      |> File.read!()
      |> :srpc_lib.init()

    children = [ConnectionServer, ConnectionSupervisor]

    opts = [
      strategy: :one_for_one,
      name: SrpcClient.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end

  ## ===============================================================================================
  ##
  ##  Public
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def connect, do: GenServer.call(ConnectionServer, :lib)

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def connect(uid, pw), do: GenServer.call(ConnectionServer, {:lib_user, uid, pw})

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def connect(conn, uid, pw), do: GenServer.call(ConnectionServer, {:user, conn, uid, pw})

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def connections, do: ConnectionSupervisor.connections()

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def refresh(conn), do: conn |> GenServer.call(:refresh)

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def close(conn) do
    result = conn |> GenServer.call(:close)
    ConnectionSupervisor |> Supervisor.terminate_child(conn)
    result
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def register(uid, pw), do: Registration.register(uid, pw)
  def register(conn, uid, pw), do: Registration.register(conn, uid, pw)

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def update(uid, pw), do: Registration.update(uid, pw)
  def update(conn, uid, pw), do: Registration.update(conn, uid, pw)

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def info(conn), do: conn |> GenServer.call(:info)
  def info(conn, :full), do: conn |> GenServer.call({:info, :full})

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def get(conn, path, body \\ "", headers \\ []) when is_binary(path) and is_binary(body) do
    conn |> request({:GET, path, body, headers})
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def post(conn, path, body, headers \\ []) when is_binary(path) and is_binary(body) do
    conn |> request({:POST, path, body, headers})
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def request(conn, {method, path}), do: request(conn, {method, path, "", []})
  def request(conn, {method, path, body}), do: request(conn, {method, path, body, []})

  def request(conn, {method, path, body, headers} = params)
      when is_atom(method) and is_binary(path) and is_binary(body) and is_list(headers) do
    conn |> GenServer.call({:request, params})
  end

  def request(_conn, _params), do: {:error, "Invalid request parameters"}

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##  Return require configuration option or raise a fuss
  ## -----------------------------------------------------------------------------------------------
  defp required_opt(opt) do
    unless value = Application.get_env(:srpc_client, opt) do
      raise SrpcClient.Error, message: "SrpcClient: Required configuration for #{opt} missing"
    end

    value
  end
end
