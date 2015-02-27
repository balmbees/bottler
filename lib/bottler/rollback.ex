require Logger, as: L
require Bottler.Helpers, as: H
alias SSHEx, as: S

defmodule Bottler.Rollback do
  # alias Bottler.SSH

  @moduledoc """
    Simply move the _current_ link to the previous release and restart to
    apply. It's also possible to deploy a previous release, but this is
    quite faster.

    Be careful because the _previous release_ may be different on each server.
    It's up to you to keep all your servers rollback-able (yeah).
  """

  @doc """
    Move the _current_ link to the previous r8elease and restart to apply.
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def rollback(config) do
    :ssh.start
    {:ok, _} = config[:servers] |> Keyword.values # each ip
    |> Enum.map(fn(s) -> s ++ [ user: config[:remote_user] ] end) # add user
    |> H.in_tasks( fn(args) -> on_server(args) end )

    Bottler.Restart.restart config
  end

  defp on_server(args) do
    ip = args[:ip] |> to_char_list
    user = args[:user] |> to_char_list

    :ssh.start
    {:ok, conn} = :ssh.connect(ip, 22,
                        [{:user,user},{:silently_accept_hosts,true},
                         {:user_dir, '#{System.get_env "HOME"}/keys'}], 5000)

    previous = get_previous_release conn, user

    L.info "Rollback to #{previous} on #{ip}..."

    shift_current conn, user, previous
    :ok
  end

  defp get_previous_release(conn, user) do
    app = Mix.Project.get!.project[:app]
    res = S.cmd! conn, 'ls -t /home/#{user}/#{app}/releases'
    res |> String.split |> Enum.at(1)
  end

  defp shift_current(conn, user, vsn) do
    app = Mix.Project.get!.project[:app]
    S.cmd! conn, 'ln -sfn /home/#{user}/#{app}/releases/#{vsn} ' ++
                 ' /home/#{user}/#{app}/current'
  end

end
