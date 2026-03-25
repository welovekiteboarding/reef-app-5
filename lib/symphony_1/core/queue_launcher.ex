defmodule Symphony1.Core.QueueLauncher do
  alias Symphony1.Core.RunCoordinator

  @spec launch(map()) :: {:ok, Task.t()} | :none | {:error, term()}
  def launch(attrs) do
    with {:ok, run} <- RunCoordinator.run_issue(attrs) do
      {:ok, Task.async(fn -> RunCoordinator.finish_claimed_issue(run, attrs) end)}
    end
  end
end
