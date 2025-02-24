<#
.SYNOPSIS
  Rebase via merge script in PowerShell

.DESCRIPTION
  A PowerShell rewrite of the original Bash script:
  https://github.com/capslocky/git-rebase-via-merge

  This script:
   1) Checks the current branch & base branch conditions
   2) Creates a hidden merge commit in a detached HEAD
   3) Rebases the original branch onto the base branch
   4) Optionally creates one more commit if the final tree differs
      from the hidden merge result
   5) Handles conflicts interactively for both the merge and rebase
#>

param(
    [string]
    $BaseBranch = "origin/stage"
)

$ErrorActionPreference = "Stop"

function Main {

    Write-Host "This script will perform rebase via merge."
    Write-Host ""

    Init

    # 1) Checkout a detached HEAD at the current branch commit
    git checkout --quiet $Script:CurrentBranchHash

    # 2) Merge the base branch to form a "hidden" commit
    try {
        git merge $BaseBranch -m "Hidden orphaned commit to save merge result."
    } catch {
        # We allow the script to continue so we can detect conflicts
    }
    Write-Host ""

    if (Merge-Conflicts-Present) {
        Write-Host "You have at least one merge conflict."
        Write-Host ""
        Fix-Merge-Conflicts
    }

    $hiddenResultHash = Get-Hash HEAD

    Write-Host "Merge succeeded at hidden commit:"
    Write-Host "$hiddenResultHash"
    Write-Host ""

    Write-Host "Starting rebase, resolving any conflicts automatically with -X theirs."

    git checkout --quiet $Script:CurrentBranch
    try {
        git rebase $BaseBranch -X theirs
    } catch {
        # We'll handle conflicts below if they exist
    }

    if (Rebase-Conflicts-Present) {
        Write-Host "You have at least one rebase conflict."
        Write-Host ""
        Fix-Rebase-Conflicts
    }

    $currentTree = git cat-file -p HEAD | Select-String "tree"
    $resultTree  = git cat-file -p $hiddenResultHash | Select-String "tree"

    if ($currentTree -ne $resultTree) {
        Write-Host "Restoring project state from the hidden merge with a single additional commit."
        Write-Host ""

        $additionalCommitMessage = "Rebase via merge. '$($Script:CurrentBranch)' rebased on '$BaseBranch'."
        $additionalCommitHash = git commit-tree "$hiddenResultHash^{tree}" -p HEAD -m $additionalCommitMessage

        git merge --ff $additionalCommitHash
        Write-Host ""
    }
    else {
        Write-Host "No additional commit needed. The project state matches the hidden merge result."
    }

    Write-Host "Done."
    exit 0
}

function Init {
    $Script:CurrentBranch = git symbolic-ref --short HEAD
    if (-not $Script:CurrentBranch) {
        Write-Host "Can't rebase. There is no current branch (detached HEAD)."
        exit 1
    }

    $baseBranchHash = Get-Hash $BaseBranch
    $Script:CurrentBranchHash = Get-Hash $Script:CurrentBranch

    if (-not $baseBranchHash) {
        Write-Host "Can't rebase. Base branch '$BaseBranch' not found."
        exit 1
    }

    Write-Host "Current branch:"
    Write-Host "$($Script:CurrentBranch) ($($Script:CurrentBranchHash))"
    Show-Commit $Script:CurrentBranchHash
    Write-Host ""

    Write-Host "Base branch:"
    Write-Host "$BaseBranch ($baseBranchHash)"
    Show-Commit $baseBranchHash
    Write-Host ""

    $changedFiles = Get-Any-Changed-Files
    if ($changedFiles) {
        Write-Host "Can't rebase. You need to commit or stash changes in the following files:"
        Write-Host ""
        $changedFiles | ForEach-Object { Write-Host $_ }
        exit 1
    }

    if ($baseBranchHash -eq $Script:CurrentBranchHash) {
        Write-Host "Can't rebase. Current branch is equal to the base branch."
        exit 1
    }

    $revList1 = git rev-list $BaseBranch ^$($Script:CurrentBranch)
    if (-not $revList1) {
        Write-Host "Can't rebase. Current branch is already rebased."
        exit 1
    }

    $revList2 = git rev-list ^$BaseBranch $Script:CurrentBranch
    if (-not $revList2) {
        Write-Host "Can't rebase. Current branch has no unique commits. You can do fast-forward merge."
        exit 1
    }

    while ($true) {
        $input = (Read-Host "Continue (c) / Abort (a)").Trim().ToLower()
        Write-Host ""

        if ($input -eq "c") {
            break
        }
        elseif ($input -eq "a") {
            Write-Host "Aborted."
            exit 1
        }
        else {
            Write-Host "Invalid option."
            Write-Host "Type 'c' to Continue or 'a' to Abort."
            Write-Host ""
        }
    }
}

function Merge-Conflicts-Present {
    $repoRoot = git rev-parse --show-toplevel
    return Test-Path "$repoRoot\.git\MERGE_HEAD"
}

function Rebase-Conflicts-Present {
    $conflictFiles = git diff --name-only --diff-filter=U --relative
    return (-not [string]::IsNullOrEmpty($conflictFiles))
}

function Fix-Merge-Conflicts {
    while ($true) {
        Write-Host "Fix all conflicts in the following files, stage all changes, then type 'c':"
        $unstaged = Get-Unstaged-Files

        if ($unstaged) {
            $unstaged | ForEach-Object { Write-Host $_ }
        } else {
            Write-Host "[No unstaged files found]"
        }
        Write-Host ""

        Write-Host "List of conflict markers:"
        Get-Files-With-Conflict-Markers
        Write-Host ""

        $input = (Read-Host "Continue (c) / Abort (a)").Trim().ToLower()
        Write-Host ""

        if ($input -eq "c") {
            $unstaged = Get-Unstaged-Files
            if (-not $unstaged) {
                git commit -m "Hidden orphaned commit to save merge result."
                break
            } else {
                Write-Host "There are still unstaged files."
                $unstaged | ForEach-Object { Write-Host $_ }
                Write-Host ""
            }
        }
        elseif ($input -eq "a") {
            Write-Host "Aborting merge."
            git merge --abort
            git checkout $Script:CurrentBranch
            Write-Host "Aborted."
            exit 2
        }
        else {
            Write-Host "Invalid option."
            Write-Host "Type 'c' to Continue or 'a' to Abort."
            Write-Host ""
        }
    }
}

function Fix-Rebase-Conflicts {
    while ($true) {
        Write-Host "Fix all conflicts in the following files, stage all changes, then type 'c':"
        $unstaged = Get-Unstaged-Files

        if ($unstaged) {
            $unstaged | ForEach-Object { Write-Host $_ }
        } else {
            Write-Host "[No unstaged files found]"
        }
        Write-Host ""

        Write-Host "List of conflict markers:"
        Get-Files-With-Conflict-Markers
        Write-Host ""

        $input = (Read-Host "Continue (c) / Abort (a)").Trim().ToLower()
        Write-Host ""

        if ($input -eq "c") {
            $unstaged = Get-Unstaged-Files
            if (-not $unstaged) {
                git rebase --continue
                break
            } else {
                Write-Host "There are still unstaged files."
                $unstaged | ForEach-Object { Write-Host $_ }
                Write-Host ""
            }
        }
        elseif ($input -eq "a") {
            Write-Host "Aborting rebase."
            git rebase --abort
            git checkout $Script:CurrentBranch
            Write-Host "Aborted."
            exit 2
        }
        else {
            Write-Host "Invalid option."
            Write-Host "Type 'c' to Continue or 'a' to Abort."
            Write-Host ""
        }
    }
}

function Get-Hash($ref) {
    try {
        return (git rev-parse --short $ref)
    }
    catch {
        return $null
    }
}

function Show-Commit($commitHash) {
    git log -n 1 --pretty=format:"%<(20)%an | %<(14)%ar | %s" $commitHash
}

function Get-Any-Changed-Files {
    git status --porcelain --ignore-submodules=dirty |
        ForEach-Object { $_.Substring(3) }
}

function Get-Unstaged-Files {
    git status --porcelain --ignore-submodules=dirty |
        Where-Object { $_ -notmatch "^. " } |
        ForEach-Object { $_.Substring(3) }
}

function Get-Files-With-Conflict-Markers {
    git diff --check
}

Main
