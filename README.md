# Git Rebase via Merge

Have you ever rebased a branch, resolving many conflicts on multiple commits?
Yes, that's a sad story. It wouldn't be so sad if it was a merge instead, because with merges, you typically fix only the final conflicts once.

## The Method

Here’s the idea for making a potentially hard rebase much easier:

1. **Start a hidden merge**
   - In a detached HEAD, merge the base branch into your feature branch’s latest commit. This produces a “hidden” or “orphan” merge commit.

2. **Resolve conflicts (if any) and save the hidden merge result**
   - You only fix these conflicts once, just like a normal merge.

3. **Perform a standard branch rebase of your feature branch onto the base branch**
   - Use automatic conflict resolution (e.g., `-X theirs`).

4. **Restore the hidden result as a single additional commit**
   - This happens if the rebased code tree differs from the hidden merge’s tree.

This way, you get a linear history from rebase and the ease of only needing to fix conflicts once (the same as a single merge commit).

---

## Setup

You can choose one of the two scripts depending on your environment:

### 1. Bash Version (Linux / Mac / Windows with Git-Bash)

#### Get the Script
```bash
# Download the script
curl -L https://git.io/rebase-via-merge -o ~/git-rebase-via-merge.sh

# Make it executable
chmod +x ~/git-rebase-via-merge.sh
```
If you want to place it somewhere else, feel free to do so—just remember to use the correct path when calling it later.

#### Change the Default Base Branch (Optional)
Inside the script file (e.g., `~/git-rebase-via-merge.sh`), find the line:
```bash
default_base_branch="origin/master"
```
and change it to whatever you prefer, for example:
```bash
default_base_branch="origin/develop"
```

#### Usage
Whenever you want to do a rebase, run the script instead of `git rebase`. For example:
```bash
# Default base (origin/master)
~/git-rebase-via-merge.sh
```
This is effectively your new “rebase” command. Or, if you want to rebase on a different base branch, say `origin/develop`, then:
```bash
~/git-rebase-via-merge.sh origin/develop
```
That’s it! The script will prompt you through each step, handle conflicts interactively, and produce a single additional commit if needed.

---

### 2. PowerShell Version (Windows)
If you’d like to run this script natively in Windows PowerShell (instead of Git-Bash), you can use the `.ps1` version.

#### Get the Script
1. Create a new file (e.g., `git-rebase-via-merge.ps1`) in your Git repo or somewhere on your computer.
2. Copy the PowerShell script into that file. You can obtain the script from this repo (or from a provided link in your documentation).

#### Allow PowerShell Scripts to Run
By default, Windows may block `.ps1` script execution. Open an elevated PowerShell and run:
```powershell
Set-ExecutionPolicy RemoteSigned
```
(Or an appropriate policy for your environment.)

#### Usage
Open a PowerShell terminal in your repo directory and run:
```powershell
.\git-rebase-via-merge.ps1
```
By default, it will try to rebase on `origin/develop` (or whatever default you set inside the script).

If you want a different base branch, do:
```powershell
.\git-rebase-via-merge.ps1 origin/main
```

The script will:
- Check that you’re on a valid branch (not detached).
- Create a hidden merge in a detached HEAD.
- Resolve conflicts in one go if needed.
- Rebase your branch on the base branch with auto conflict resolution.
- Compare the final tree with the hidden merge’s tree.
- Optionally add one commit if they differ.

---

## Notes and Testing

### Testing on a Temp Branch
You can test the script on a throwaway branch:
```bash
git checkout -b test-of-rebase-via-merge
```
Make some commits, diverge from your base branch, then run the script. That way, you can see how it handles conflicts and commit states without risking important code.

### No Unique Commits
If your feature branch has no unique commits compared to the base, you can just do a normal fast-forward merge. The script will detect this and exit.

### Already Rebased
If you’ve already rebased (or the base branch is fully included in your branch), the script will tell you there’s nothing to do.

### Interactive Prompts
If there are conflicts, the script will display a list of conflicted files. You fix them, stage them, and type `c` to continue or `a` to abort.

### Works Offline
No dependencies beyond Git and either Bash (for the `.sh` script) or PowerShell (for the `.ps1` script).

---

## Why This Approach?

- **Rebase** is great for a clean, linear history.
- **Merge** is often simpler because you only fix conflicts once.
- **This script merges the two methods** to give you the best of both worlds.

## Summary
- Pick **Bash** or **PowerShell**—whichever suits your OS/workflow.
- Install (place in `~/` or somewhere convenient, make executable if Bash).
- Use it in place of `git rebase` when your branch may have lots of conflicts.
- Enjoy only **one conflict resolution step** (the hidden merge), plus a clean, linear commit history after rebase.

---

