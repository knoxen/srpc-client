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
    conn_pid |> request({:GET, path, body, headers})
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def post(conn_pid, path, body, headers \\ []) when is_binary(path) and is_binary(body) do
    conn_pid |> request({:POST, path, body, headers})
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def request(conn_pid, {method, path}), do: request(conn_pid, {method, path, "", []})
  def request(conn_pid, {method, path, body}), do: request(conn_pid, {method, path, body, []})

  def request(conn_pid, {method, path, body, headers} = params)
  when is_atom(method) and is_binary(path) and is_binary(body) and is_list(headers) do
    conn_pid |> GenServer.call({:request, params})
  end

  def request(_conn_pid, _params), do: {:error, "Invalid request parameters"}

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
