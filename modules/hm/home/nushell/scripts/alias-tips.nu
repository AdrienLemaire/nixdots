def alias_tips [] {
  let command = (commandline | str trim)
  let aliases = (help aliases | select name expansion)
  let found_aliases = ($aliases | where { |alias| $command | str starts-with $alias.expansion })

  if ($found_aliases | length) > 0 {
    print -r ($found_aliases | each { |alias| print -n $"Tip: \e[1;32m($alias.name)\e[0m → \e[1m($alias.expansion)\e[0m\n" })
    print ""
  }
}

$env.config = ($env.config | upsert hooks.pre_execution [ { alias_tips } ])
