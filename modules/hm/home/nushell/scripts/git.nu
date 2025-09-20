#
# Functions Current
# (sorted alphabetically by function name)
# (order should follow README)
#

def git_current_branch [] {
  git symbolic-ref --short HEAD
}

# Check for develop and similarly named branches
def git_develop_branch [] {
  if (git rev-parse --git-dir | complete | get exit_code) != 0 {
    return
  }
  let branches = ["dev", "devel", "develop", "development"]
  for branch in $branches {
    if (git show-ref -q --verify $"refs/heads/($branch)" | complete | get exit_code) == 0 {
      echo $branch
      return 0
    }
  }
  echo "develop"
  return 1
}

# Check if main exists and use instead of master
def git_main_branch [] {
  if (git rev-parse --git-dir | complete | get exit_code) != 0 {
    return
  }
  let refs = ["refs/heads/main", "refs/heads/trunk", "refs/heads/mainline", "refs/heads/default", "refs/heads/stable", "refs/heads/master"]
  for ref in $refs {
    if (git show-ref -q --verify $ref | complete | get exit_code) == 0 {
      return ($ref | split row '/' | last)
    }
  }
  return "master"
}

def grename [old_branch: string, new_branch: string] {
  if ($old_branch | is-empty) or ($new_branch | is-empty) {
    echo "Usage: grename old_branch new_branch"
    return 1
  }

  # Rename branch locally
  git branch -m $old_branch $new_branch
  # Rename branch in origin remote
  if (git push origin $":($old_branch)" | complete | get exit_code) == 0 {
    git push --set-upstream origin $new_branch
  }
}

#
# Functions Work in Progress (WIP)
# (sorted alphabetically by function name)
# (order should follow README)
#

# Similar to `gunwip` but recursive "Unwips" all recent `--wip--` commits not just the last one
def gunwipall [] {
  let _commit = (git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H | str trim)
  if $"_commit" != (git rev-parse HEAD | str trim) {
    git reset $_commit
  }
}

# Warn if the current branch is a WIP
def work_in_progress [] {
  if (git -c log.showSignature=false log -n 1 2>/dev/null | grep -q -- "--wip--") {
    echo "WIP!!"
  }
}

#
# Aliases
# (sorted alphabetically by command)
# (order should follow README)
# (in some cases force the alisas order to match README, like for e

alias ggpur = ggu
alias g = git
alias ga = git add
alias gaa = git add --all
alias gapa = git add --patch
alias gau = git add --update
alias gav = git add --verbose
alias gam = git am
alias gama = git am --abort
alias gamc = git am --continue
alias gamscp = git am --show-current-patch
alias gams = git am --skip
alias gap = git apply
alias gapt = git apply --3way
alias gbs = git bisect
alias gbsb = git bisect bad
alias gbsg = git bisect good
alias gbsn = git bisect new
alias gbso = git bisect old
alias gbsr = git bisect reset
alias gbss = git bisect start
alias gbl = git blame -w
alias gb = git branch
alias gba = git branch --all
alias gbd = git branch --delete
alias gbD = git branch --delete --force

def gbda [] {
  git branch --no-color --merged | lines | where {|x| not ($x | str contains "master" or $x | str contains "develop")} | each {|x| git
 branch --delete ($x | str trim)}
}

alias gbm = git branch --move
alias gbnm = git branch --no-merged
alias gbr = git branch --remote
alias ggsup = git branch --set-upstream-to=origin/(git_current_branch)
alias gcor = git checkout --recurse-submodules
alias gcb = git checkout -b
alias gcB = git checkout -B
alias gcd = git checkout (git_develop_branch)
alias gcm = git checkout (git_main_branch)
alias gcp = git cherry-pick
alias gcpa = git cherry-pick --abort
alias gcpc = git cherry-pick --continue
alias gclean = git clean --interactive -d
alias gcl = git clone --recurse-submodules
alias gclf = git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules

def gccd [...args] {
  let repo = ($args | last)
  if (git clone --recurse-submodules $args | complete | get exit_code) == 0 {
    if ($repo | path exists) {
      cd $repo
    } else {
      cd ($repo | path parse | get stem)
    }
  }
}

alias gcam = git commit --all --message
alias gcas = git commit --all --signoff
alias gcasm = git commit --all --signoff --message
alias gcs = git commit --gpg-sign
alias gcss = git commit --gpg-sign --signoff
alias gcssm = git commit --gpg-sign --signoff --message
alias gcmsg = git commit --message
alias gcsm = git commit --signoff --message
alias gc = git commit --verbose
alias gca = git commit --verbose --all
alias gca! = git commit --verbose --all --amend
alias gcan! = git commit --verbose --all --no-edit --amend
alias gcans! = git commit --verbose --all --signoff --no-edit --amend
alias gcann! = git commit --verbose --all --date=now --no-edit --amend
alias gc! = git commit --verbose --amend
alias gcn = git commit --verbose --no-edit
alias gcn! = git commit --verbose --no-edit --amend
alias gcf = git config --list
alias gdct = git describe --tags (git rev-list --tags --max-count=1)
alias gd = git diff
alias gdca = git diff --cached
alias gdcw = git diff --cached --word-diff
alias gds = git diff --staged
alias gdw = git diff --word-diff

alias gdup = git diff @{upstream}

def gdnolock [...args] {
  git diff $args ":(exclude)package-lock.json" ":(exclude)*.lock"
}

alias gdt = git diff-tree --no-commit-id --name-only -r
alias gf = git fetch
# --jobs=<n> was added in git 2.8
alias gfa = git fetch --all --tags --prune --jobs=10
alias gfo = git fetch origin
alias gg = git gui citool
alias gga = git gui citool --amend
alias ghh = git help
alias glgg = git log --graph
alias glgga = git log --graph --decorate --all
alias glgm = git log --graph --max-count=10
alias glods = git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short
alias glod = git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"
alias glola = git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all
alias glols = git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat
alias glol = git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"
alias glo = git log --oneline --decorate
alias glog = git log --oneline --decorate --graph
alias gloga = git log --oneline --decorate --graph --all

# Pretty log messages
def _git_log_prettily [format: string] {
  if ($format | is-empty) {
    git log --pretty=$format
  }
}

alias glp = _git_log_prettily
alias glg = git log --stat
alias glgp = git log --stat --patch
alias gignored = git ls-files -v | grep "^[[:lower:]]"
alias gfg = git ls-files | grep
alias gm = git merge
alias gma = git merge --abort
alias gmc = git merge --continue
alias gms = git merge --squash
alias gmff = git merge --ff-only
alias gmom = git merge origin/(git_main_branch)
alias gmum = git merge upstream/(git_main_branch)
alias gmtl = git mergetool --no-prompt
alias gmtlvim = git mergetool --no-prompt --tool=vimdiff

alias gl = git pull
alias gpr = git pull --rebase
alias gprv = git pull --rebase -v
alias gpra = git pull --rebase --autostash
alias gprav = git pull --rebase --autostash -v

def ggu [branch: string] {
  if ($branch | is-empty) {
    let branch = (git_current_branch)
  }
  git pull --rebase origin $branch
}

alias gprom = git pull --rebase origin (git_main_branch)
alias gpromi = git pull --rebase=interactive origin (git_main_branch)
alias gprum = git pull --rebase upstream (git_main_branch)
alias gprumi = git pull --rebase=interactive upstream (git_main_branch)
alias ggpull = git pull origin (git_current_branch)

def ggl [...args] {
  if ($args | length) == 0 {
    let branch = (git_current_branch)
    git pull origin $branch
  } else {
    git pull origin $args
  }
}

alias gluc = git pull upstream (git_current_branch)
alias glum = git pull upstream (git_main_branch)
alias gp = git push
alias gpd = git push --dry-run

def ggf [branch: string] {
  if ($branch | is-empty) {
    let branch = (git_current_branch)
  }
  git push --force origin $branch
}

alias gpf! = git push --force
alias gpf = git push --force-with-lease --force-if-includes

def ggfl [branch: string] {
  if ($branch | is-empty) {
    let branch = (git_current_branch)
  }
  git push --force-with-lease origin $branch
}

alias gpsup = git push --set-upstream origin (git_current_branch)
alias gpsupf = git push --set-upstream origin (git_current_branch) --force-with-lease --force-if-includes
alias gpv = git push --verbose
alias gpod = git push origin --delete
alias ggpush = git push origin (git_current_branch)

def ggp [...args] {
  if ($args | length) == 0 {
    let branch = (git_current_branch)
    git push origin $branch
  } else {
    git push origin $args
  }
}

alias gpu = git push upstream
alias grb = git rebase
alias grba = git rebase --abort
alias grbc = git rebase --continue
alias grbi = git rebase --interactive
alias grbo = git rebase --onto
alias grbs = git rebase --skip
alias grbd = git rebase (git_develop_branch)
alias grbm = git rebase (git_main_branch)
alias grbom = git rebase origin/(git_main_branch)
alias grbum = git rebase upstream/(git_main_branch)
alias grf = git reflog
alias gr = git remote
alias grv = git remote --verbose
alias gra = git remote add
alias grrm = git remote remove
alias grmv = git remote rename
alias grset = git remote set-url
alias grup = git remote update
alias grh = git reset
alias gru = git reset --
alias grhh = git reset --hard
alias grhk = git reset --keep
alias grhs = git reset --soft
alias groh = git reset origin/(git_current_branch) --hard
alias grs = git restore
alias grss = git restore --source
alias grst = git restore --staged
alias grev = git revert
alias greva = git revert --abort
alias grevc = git revert --continue
alias grm = git rm
alias grmc = git rm --cached
alias gcount = git shortlog --summary --numbered
alias gsh = git show
alias gsps = git show --pretty=short --show-signature
alias gstall = git stash --all
alias gstaa = git stash apply
alias gstc = git stash clear
alias gstd = git stash drop
alias gstl = git stash list
alias gstp = git stash pop
# use the default stash push on git 2.13 and newer
alias gsta = git stash push
alias gsts = git stash show --patch
alias gs = git status
alias gst = git status
alias gss = git status --short
alias gsb = git status --short --branch
alias gsi = git submodule init
alias gsu = git submodule update
alias gsd = git svn dcommit
alias gsr = git svn rebase
alias gsw = git switch
alias gswc = git switch --create
