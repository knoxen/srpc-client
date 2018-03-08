defmodule SrpcClient.Registration do
  alias :srpc_lib, as: SrpcLib
  alias SrpcClient.Action, as: SrpcAction
  alias SrpcClient.Msg, as: SrpcMsg

  @reg_create 1
  @reg_update 2
  @reg_ok 10
  @reg_dup 11
  @reg_not_found 12

  ## ===============================================================================================
  ##
  ##  Public
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def register(user_id, password) do
    lib_exec(&register/4, user_id, password)
  end

  def register(conn_pid, user_id, password, reconnect? \\ true) do
    registration_action(conn_pid, @reg_create, user_id, password, reconnect?)
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def update(user_id, password) do
    lib_exec(&update/4, user_id, password)
  end

  def update(conn_pid, user_id, password, reconnect? \\ true) do
    registration_action(conn_pid, @reg_update, user_id, password, reconnect?)
  end

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp lib_exec(reg_fun, user_id, password) do
    case SrpcClient.connect() do
      {:ok, conn_pid} ->
        result = reg_fun.(conn_pid, user_id, password, false)
        SrpcClient.close(conn_pid)
        result

      error ->
        error
    end
  end

  defp registration_action(conn_pid, action, user_id, password, reconnect?) do
    result =
      conn_pid
      |> refresh()
      |> registration_request(action, user_id, password, reconnect?)
      |> case do
        {:ok, {@reg_ok, _data}, pid} ->
          {:ok, pid}

        {:ok, {@reg_dup, _data}, pid} ->
          {{:error, "User already registered"}, pid}

        {:ok, {@reg_not_found, _data}, pid} ->
          {{:error, "User registeration not found"}, pid}

        error ->
          error
      end

    registration_response(result, reconnect?)
  end

  require Logger

  defp registration_request(conn_pid, reg_code, user_id, password, reconnect?, retry? \\ true) do
    conn = conn_pid |> SrpcClient.info(:full)

    case create_registration_request(conn, reg_code, user_id, password) do
      {:ok, nonce, encrypted_request} ->
        case register_action(conn, encrypted_request, reconnect?) do
          {{:ok, encrypted_response}, ^conn_pid} ->
            process_registration_response(conn, nonce, encrypted_response)

          {:noop, new_conn_pid} ->
            if retry? do
              registration_request(new_conn_pid, reg_code, user_id, password, reconnect?, false)
            else
              {{:error, "Registration with stale connection"}, conn_pid}
            end

          error ->
            error
        end

      error ->
        error
    end
  end

  defp register_action(conn, encrypted_request, false) do
    {conn |> SrpcAction.register(encrypted_request, false), conn.pid}
  end

  defp register_action(conn, encrypted_request, true) do
    conn |> SrpcAction.register(encrypted_request, true)
  end

  defp create_registration_request(conn, reg_code, user_id, password) do
    {nonce, client_data} = SrpcMsg.wrap(conn)

    case SrpcLib.create_registration_request(conn, reg_code, user_id, password, client_data) do
      {:ok, encrypted_request} ->
        {:ok, nonce, encrypted_request}

      error ->
        {reason(error, "Create registration request"), conn.conn_pid}
    end
  end

  defp process_registration_response(conn, nonce, encrypted_response) do
    case SrpcLib.process_registration_response(conn, encrypted_response) do
      {:ok, {return_code, registration_response}} ->
        case SrpcMsg.unwrap(nonce, registration_response) do
          {:ok, data} ->
            {:ok, {return_code, data}, conn.pid}

          error ->
            {reason(error, "Registration unwrap"), conn.pid}
        end

      error ->
        {reason(error, "Process registration response"), conn.pid}
    end
  end

  defp reason({:error, reason}, msg) do
    {:error, msg <> " error: " <> reason}
  end

  defp reason({:invalid, 403}, msg) do
    {:error, msg <> " invalid: Stale connection"}
  end

  defp refresh(conn_pid) do
    if GenServer.call(conn_pid, :old?) or GenServer.call(conn_pid, :tired?) do
      GenServer.call(conn_pid, :refresh)
    end

    conn_pid
  end

  defp registration_response({result, _pid}, false) do
    result
  end

  defp registration_response(result, true) do
    result
  end
end
