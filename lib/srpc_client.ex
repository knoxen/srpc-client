defmodule SrpcClient do
  @moduledoc """
  Documentation for SrpcClient.
  """

  alias SrpcClient.{ConnectionServer, ConnectionSupervisor, Opt, Registration}

  use Application

  def start(_type, []) do
    Process.register(self(), __MODULE__)

    :ok =
      Opt.srpc_file()
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
  def refresh(conn_pid), do: conn_pid |> GenServer.call(:refresh)

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def close(conn_pid) do
    result = conn_pid |> GenServer.call(:close)
    ConnectionSupervisor |> Supervisor.terminate_child(conn_pid)
    result
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def register(uid, pw), do: Registration.register(uid, pw)
  def register(conn_pid, uid, pw), do: Registration.register(conn_pid, uid, pw)

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def update(uid, pw), do: Registration.update(uid, pw)
  def update(conn_pid, uid, pw), do: Registration.update(conn_pid, uid, pw)

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def info(conn_pid), do: conn_pid |> GenServer.call(:info)
  def info(conn_pid, :full), do: conn_pid |> GenServer.call({:info, :full})

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def get(conn_pid, path, body \\ "", headers \\ []) when is_binary(path) and is_binary(body) do
    conn_pid
    |> request(%SrpcClient.Request{method: :GET, path: path, body: body, headers: headers})
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def post(conn_pid, path, body, headers \\ []) when is_binary(path) and is_binary(body) do
    conn_pid
    |> request(%SrpcClient.Request{method: :POST, path: path, body: body, headers: headers})
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def request(conn_pid, request) do
    if GenServer.call(conn_pid, :old?) or GenServer.call(conn_pid, :tired?) do
      GenServer.call(conn_pid, :refresh)
    end

    conn_pid
    |> GenServer.call({:app, request})
  end
end
