defmodule Symphony1.Project.Setup do
  alias Symphony1.Core.Linear
  alias Symphony1.Project.{LinearBrowserFallback, SetupIntent, SetupState}

  @intent_path "config/symphony_setup.json"
  @state_path "config/symphony_setup.state.json"

  @spec run() :: {:ok, map()} | {:error, term()}
  def run do
    with {:ok, intent} <- SetupIntent.load(@intent_path),
         :ok <- SetupState.write(@state_path, verified_state(intent)),
         :ok <- maybe_create_proof_issue(intent),
         {:ok, state} <- SetupState.read(@state_path) do
      {:ok, state}
    end
  end

  defp verified_state(intent) do
    env_blockers = missing_env_blockers(intent)
    github_blockers = github_blockers(intent)
    blockers = env_blockers ++ github_blockers

    %{
      "project" => %{
        "name" => get_in(intent, ["project", "name"])
      },
      "steps" => %{
        "intent_loaded" => true,
        "env_verified" => env_blockers == [],
        "github_verified" => github_blockers == []
      },
      "blockers" => blockers
    }
  end

  defp missing_env_blockers(intent) do
    intent
    |> get_in(["env", "required"])
    |> Enum.reject(&System.get_env/1)
    |> Enum.map(fn env_var -> "missing_#{String.downcase(env_var)}" end)
  end

  defp github_blockers(intent) do
    expected_repo = get_in(intent, ["github", "repo"])

    case System.cmd("git", ["remote", "get-url", "origin"], stderr_to_stdout: true) do
      {url, 0} ->
        normalized_url = String.trim(url)

        if String.contains?(normalized_url, expected_repo) do
          []
        else
          ["origin_remote_mismatch"]
        end

      {_output, _status} ->
        ["missing_origin_remote"]
    end
  end

  defp maybe_create_proof_issue(intent) do
    with {:ok, state} <- SetupState.read(@state_path) do
      if state["blockers"] == [] do
        case create_proof_issue(intent) do
          {:ok, proof_issue, metadata} ->
            SetupState.update(@state_path, fn current ->
              current
              |> put_in(["steps", "proof_issue_created"], true)
              |> put_in(["steps", "linear_verified"], true)
              |> put_in(["steps", "linear_browser_fallback_used"], metadata[:browser_fallback_used] || false)
              |> Map.put("proof_issue", %{"identifier" => proof_issue.identifier})
            end)

          {:error, reason, metadata} ->
            SetupState.update(@state_path, fn current ->
              current
              |> put_in(["steps", "proof_issue_created"], false)
              |> put_in(["steps", "linear_verified"], false)
              |> put_in(["steps", "linear_browser_fallback_used"], metadata[:browser_fallback_used] || false)
              |> Map.update("blockers", [blocker_for(reason)], fn blockers ->
                blockers
                |> Kernel.++([blocker_for(reason)])
                |> Enum.uniq()
              end)
            end)
            |> case do
              :ok -> {:error, reason}
              other -> other
            end

          {:error, reason} ->
            {:error, reason}
        end
      else
        SetupState.update(@state_path, fn current ->
          current
          |> put_in(["steps", "proof_issue_created"], false)
          |> put_in(["steps", "linear_verified"], false)
          |> put_in(["steps", "linear_browser_fallback_used"], false)
        end)
      end
    end
  end

  defp create_proof_issue(intent, opts \\ []) do
    requester = Application.get_env(:symphony_1, :setup_linear_requester, &Linear.request/3)

    issue_attrs = %{
      "description" => get_in(intent, ["proof_issue", "description"]),
      "state" => get_in(intent, ["proof_issue", "state"]),
      "title" => get_in(intent, ["proof_issue", "title"])
    }

    linear_config = %{
      api_key: System.fetch_env!("LINEAR_API_KEY"),
      team_key: get_in(intent, ["linear", "team_key"])
    }

    case Linear.create_issue(linear_config, issue_attrs, requester) do
      {:ok, proof_issue} ->
        {:ok, proof_issue, %{browser_fallback_used: Keyword.get(opts, :browser_fallback_used, false)}}

      {:error, {:team_not_found, _team_key}} ->
        if Keyword.get(opts, :browser_fallback_used, false) do
          {:error, {:team_not_found, linear_config.team_key}, %{browser_fallback_used: true}}
        else
          case browser_setup_fallback(intent) do
            :ok ->
              create_proof_issue(intent, browser_fallback_used: true)

            {:error, reason} ->
              {:error, reason, %{browser_fallback_used: false}}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp browser_setup_fallback(intent) do
    fallback =
      Application.get_env(:symphony_1, :setup_linear_browser_fallback, &LinearBrowserFallback.run/1)

    fallback.(
      team_key: get_in(intent, ["linear", "team_key"]),
      team_name: get_in(intent, ["linear", "team_name"]),
      workflow_states: get_in(intent, ["linear", "workflow_states"])
    )
  end

  defp blocker_for(:linear_browser_fallback_unavailable), do: "linear_browser_fallback_unavailable"
  defp blocker_for({:linear_browser_fallback_command_failed, _output}), do: "linear_browser_fallback_command_failed"
  defp blocker_for({:team_not_found, _team_key}), do: "linear_team_not_found"
  defp blocker_for(reason), do: "setup_error:#{inspect(reason)}"
end
