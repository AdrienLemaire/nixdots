# Nushell Config File
#
# version = "0.101.0"

$env.config.show_banner = false
# $env.config.shell_integration.osc133 = true
$env.config.edit_mode = 'vi'
$env.config.buffer_editor = 'vi'
$env.config.history.max_size = 5_000_000
$env.config.history.file_format = "sqlite"

use ~/.cache/starship/init.nu
use ai.nu/ai *
use ai.nu/ai/shortcut.nu *
#use nushell_scripts/ai_tools.nu *
use nushell_scripts/network.nu *
use nushell_scripts/zoxide.nu *
use nushell_scripts/weather_tomorrow.nu [weather,get_weather_by_interval]
source git.nu
source alias-tips.nu

alias vi = nvim
alias vim = nvim

source ~/Projects/3rdPart/nushell/catppuccin-nushell/themes/catppuccin_mocha.nu
source ~/.cache/carapace/init.nu
source ~/.config/nushell/completions/vectorcode.nu
source ~/.zoxide.nu
#source '~/Projects/3rdPart/nushell/nu_scripts/sourced/todo.nu'
# use nu_scripts/modules/background_task/task.nu
