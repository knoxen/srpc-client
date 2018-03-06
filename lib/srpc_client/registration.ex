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

  def register(conn_pid, user_id, password, check_stale \\ true) do
    result =
      conn_pid
      |> registration_request(@reg_create, user_id, password)
      |> case do
        {:ok, {@reg_ok, _data}} ->
          :ok

        {:ok, {@reg_dup, _data}} ->
          {:error, "User already registered"}

        error ->
          error
      end

    registration_response(result, conn_pid, check_stale)
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  def update(user_id, password) do
    lib_exec(&update/4, user_id, password)
  end

  def update(conn_pid, user_id, password, check_stale \\ true) do
    result =
      conn_pid
      |> registration_request(@reg_update, user_id, password)
      |> case do
        {:ok, {@reg_ok, _data}} ->
          :ok

        {:ok, {@reg_not_found, _data}} ->
          {:error, "User registeration not found"}

        error ->
          error
      end

    registration_response(result, conn_pid, check_stale)
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

  defp registration_request(conn_pid, reg_code, user_id, password) do
    conn = conn_pid |> SrpcClient.info(:full)
    {nonce, client_data} = SrpcMsg.wrap(conn)

    case SrpcLib.create_registration_request(conn, reg_code, user_id, password, client_data) do
      {:ok, encrypted_request} ->
        case SrpcAction.register(conn, encrypted_request) do
          {:ok, encrypted_response} ->
            case SrpcLib.process_registration_response(conn, encrypted_response) do
              {:ok, {return_code, registration_response}} ->
                case SrpcMsg.unwrap(nonce, registration_response) do
                  {:ok, data} ->
                    {:ok, {return_code, data}}

                  error ->
                    reason(error, "Registration unwrap")
                end

              error ->
                reason(error, "Process registration response")
            end

          error ->
            reason(error, "Registration action")
        end

      error ->
        reason(error, "Create registration request")
    end
  end

  defp reason({:error, reason}, msg) do
    <<msg::binary, " error: ", reason::binary>>
  end

  defp reason({:invalid, 403}, msg) do
    <<msg::binary, " invalid: Stale connection">>
  end

  defp registration_response(result, conn_pid, false) do
    result
  end

  defp registration_response(result, conn_pid, true) do
    {result, conn_pid}
  end
end
