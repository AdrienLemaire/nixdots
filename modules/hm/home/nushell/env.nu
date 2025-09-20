# Default Nushell Environment Config File
# These "sensible defaults" are set before the user's `env.nu` is loaded
#
# version = "0.101.0"

$env.PROMPT_COMMAND = $env.PROMPT_COMMAND? | default {||
    let dir = match (do -i { $env.PWD | path relative-to $nu.home-path }) {
        null => $env.PWD
        '' => '~'
        $relative_pwd => ([~ $relative_pwd] | path join)
    }

    let path_color = (if (is-admin) { ansi red_bold } else { ansi green_bold })
    let separator_color = (if (is-admin) { ansi light_red_bold } else { ansi light_green_bold })
    let path_segment = $"($path_color)($dir)(ansi reset)"

    $path_segment | str replace --all (char path_sep) $"($separator_color)(char path_sep)($path_color)"
}

$env.PROMPT_COMMAND_RIGHT = $env.PROMPT_COMMAND_RIGHT? | default {||
    # create a right prompt in magenta with green separators and am/pm underlined
    let time_segment = ([
        (ansi reset)
        (ansi magenta)
        (date now | format date '%x %X') # try to respect user's locale
    ] | str join | str replace --regex --all "([/:])" $"(ansi green)${1}(ansi magenta)" |
        str replace --regex --all "([AP]M)" $"(ansi magenta_underline)${1}")

    let last_exit_code = if ($env.LAST_EXIT_CODE != 0) {([
        (ansi rb)
        ($env.LAST_EXIT_CODE)
    ] | str join)
    } else { "" }

    ([$last_exit_code, (char space), $time_segment] | str join)
}

use std/util "path add"
# path add '~/.volta/bin'

$env.NU_LIB_DIRS ++= [
    # ($nu.data-dir | path join "nu_scripts")
    ($nu.default-config-dir | path join "scripts")
    '~/Projects/3rdPart/nushell/'
    (ls /nix/store/ | find nu_scripts | find dir -c [type] | get name | first | path join share nu_scripts)
    # '/nix/store/161iqshf9majzvkh228rbsmq5adwpc12-nu_scripts-0-unstable-2025-03-13/share/nu_scripts/'
]

$env.PROMPT_INDICATOR_VI_INSERT = "\e[32m➜ \e[0m"
$env.PROMPT_INDICATOR_VI_NORMAL = "\e[34m● \e[0m"
# $env.PROMPT_MULTILINE_INDICATOR = "\e[33m↴ \e[0m"

$env.CARAPACE_BRIDGES = 'zsh,bash' # fish,inshellisense
mkdir ~/.cache/carapace
carapace _carapace nushell | save --force ~/.cache/carapace/init.nu

mkdir ~/.cache/starship
starship init nu | save -f ~/.cache/starship/init.nu

$env.TODO = ($nu.config-path | path dirname | path join 'scripts/todo.txt')

$env.config.hooks.pre_execution = [
  alias_tips
]
$env.config.hooks.command_not_found = {
  |command_name|
  print (command-not-found $command_name | str trim)
}

$env.config.hooks.env_change.PWD = [
    # $env.config.hooks.env_change.PWD | append (source nu-hooks/nu-hooks/direnv/config.nu)
    {|before, after| direnv export json | from json | default {} | load-env }
]

$env.ANTHROPIC_API_KEY = (pass show personal/Anthropic_API)
$env.OPENAI_API_KEY = (pass show personal/OpenAI_API)

# do --env {
#     let ssh_agent_file = (
#         $nu.temp-path | path join $"ssh-agent-($env.USER? | default $env.USERNAME).nuon"
#     )
#
#     if ($ssh_agent_file | path exists) {
#         let ssh_agent_env = open ($ssh_agent_file)
#         if ($"/proc/($ssh_agent_env.SSH_AGENT_PID)" | path exists) {
#             load-env $ssh_agent_env
#             return
#         } else {
#             rm $ssh_agent_file
#         }
#     }
#
#     let ssh_agent_env = ^ssh-agent -c
#         | lines
#         | first 2
#         | parse "setenv {name} {value};"
#         | transpose --header-row
#         | into record
#     load-env $ssh_agent_env
#     $ssh_agent_env | save --force $ssh_agent_file
# }

$env.N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS = true
$env.N8N_RUNNERS_ENABLED = true
