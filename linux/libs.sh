#!/bin/bash

# beware: currently I'm reusing variables in recursive calls, so if you run functions with as arguments
# other functions of this script you may get weird/wrong results.


# check if any folder passed as parameter exists
check_folder_exist () {
  local folder_to_check=$1
  if [ ! -d "$folder_to_check" ]; then
    echo "0" # does not exist
  else
    echo "1" # exists
  fi
}

do_folder_exist () {
  # call with `do_folder_exist folder_to_check function_folder_exist function_folder_not_exist`
  local folder_to_check=$1
  local yes_func=$2
  local no_func=$3
  shift 3 # shift arguments
  local args="$@"
  if [ ! -d "$folder_to_check" ]; then
    $no_func $args
  else
    $yes_func $args
  fi
}

# check if any file passed as parameter exists
check_file_exist () {
  local file_to_check=$1
  if [ ! -e "$file_to_check" ]; then
    echo "0" # does not exist
  else
    echo "1" # exists
  fi
}

do_file_exist () {
  # call with `do_file_exist file_to_check function_file_exist function_file_not_exist`
  local file_to_check=$1
  local yes_func=$2
  local no_func=$3
  shift 3 # shift arguments
  local args="$@"
  if [ ! -e "$file_to_check" ]; then
    $no_func $args
  else 
	  $yes_func $args
  fi
}

do_variable_exist () {
  # call with var_to_check not set to the value, but to the name
  # (e.g. if you want to check variable $SOMETHING, call it as `do_variable_exist SOMETHING func1 func2` without the $)
  local var_to_check=$1
  local yes_func=$2 # executed if exists
  local no_func=$3
  shift 3 # shift arguments
  local args="$@"
  if [ ! -z "${!var_to_check+x}" ]; then
    $yes_func $args
  else
    $no_func $args
  fi
}

do_variable_non_empty () {
  # call with var_to_check not set to the value, but to the name, note that this works only if the variable is set
  local var_to_check=$1
  local yes_func=$2 # executed if not empty
  local no_func=$3
  shift 3 # shift arguments
  local args="$@"
  if [ ! -z "${!var_to_check}" ]; then
    $yes_func $args
  else
    $no_func $args
  fi
}

do_variable_exist_non_empty () {
  # call with var_to_check not set to the value, but to the name
  local var_to_check=$1
  local yes_func=$2 # executed if exists not empty
  local no_func=$3
  shift 3 # shift arguments
  local args="$@"
  if [ ! -z "${!var_to_check+x}" ] && [ ! -z "${!var_to_check}" ]; then
    $yes_func $args
  else
    $no_func $args
  fi
}

do_sourced_file() {
  # execute functions if current script has been sourced or not
  # You need to specify the source level, i.e. which is the script you want to know if it was sourced
  # If for instance you want to know if the script that sourced this lib was itself sourced, you need to use level 1
  # If you copied the func to your source script, then use level 0
  # Note: if you want to exit in both cases, you should use `exit` for both func
  # otherwise with return it will just return the current function and not the code that called it
  local source_level=$1
  local yes_func=$2
  local no_func=$3
  shift 3 # shift arguments
  local args="$@"
  if [[ "$0" == "${BASH_SOURCE[$source_level]}" ]]; then
    $no_func $args
  else
    $yes_func $args
  fi
}

# get id of a group
get_group_id () {
  # call as my_var=`get_group_id my_group_name`
  local group_name=$1
  local gr_id=`getent group $group_name | cut -d: -f3`
  echo $gr_id
}

ask_yes_no_function () {
  # call with `ask_yes_no_function "my message" function_1 function_2`
  local message=$1
  local yes_func=$2
  local no_func=$3
  shift 3 # shift arguments
  local args="$@"
  read -p "$message [y/n]: " -r
  echo  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    $yes_func $args
  elif  [[ $REPLY =~ ^[Nn]$ ]]; then 
	  $no_func $args
  else
    echo "Invalid response"
	  ask_yes_no_function $message $yes_func $no_func $args
  fi
}

do_nothing_function () {
  sleep 0.01
}

enable_color_prompt () {
  local user=$1
  maybe_run_as_root sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/' /home/$user/.bashrc
}

disable_home_share () {
  maybe_run_as_root sed -i 's/DIR_MODE=0755/DIR_MODE=0750/' /etc/adduser.conf
}

_run_as_root () {
  # Note: works only with functions that do not execute other functions
  local m_func_name=$1
  shift
  local m_args=$*
  local m_func_cont=$(declare -f $m_func_name)
  _is_function () {
    sudo bash -c "$m_func_cont; $m_func_name $m_args"
  }
  _is_command () {
    sudo $m_func_name $m_args
  }
  do_variable_non_empty m_func_cont _is_function _is_command
}

enable_run_as_root () {
  M_RUN_AS_ROOT=1
}

disable_run_as_root () {
  unset M_RUN_AS_ROOT
}

maybe_run_as_root () {
  # prepend to any command (not function) you may need to run as root
  # to actually run it as root you need to call `enable_run_as_root` right before it
  local m_func_name=$1
  shift
  m_run_as_root_explicit_func () {
    _run_as_root $m_func_name $@
  }
  do_variable_exist_non_empty M_RUN_AS_ROOT m_run_as_root_explicit_func $m_func_name $@
}

_get_pre_backup_name () {
  local m_file=$1
  echo "${m_file%.bak*[0-9]}"
}

_get_post_backup_name () {
  local m_file=$1
  local m_counter=$2
  if [[ ( -z "$m_counter" ) || ( "$m_counter" == 0 ) ]] ; then
    m_counter=""
  fi
  echo "${m_file}.bak${m_counter}"
}
 
rename_bak_file () {
  local m_out_name=$(_get_post_backup_name $1 $2)
  maybe_run_as_root cp -r "$1" "$m_out_name"
}

backup_if_folder_exists () {
  local folder_to_check=$1
  local m_counter=$2
  do_folder_exist $folder_to_check rename_bak_file do_nothing_function $folder_to_check $m_counter
}

backup_if_file_exists () {
  local file_to_check=$1
  local m_counter=$2
  do_file_exist $file_to_check rename_bak_file do_nothing_function $file_to_check $m_counter
}

incremental_backup_if_folder_exists () {
  local m_folder_to_check=$1
  local m_count=$2
  if [[ ( -z "$m_count" ) || ( "$m_count" == 0 ) ]] ; then
    m_count="0"
  fi

  rename_from_source () {
    local m_source_name=$(_get_pre_backup_name $1)
    local m_m_count=$2
    rename_bak_file $m_source_name $((m_m_count-1))
  }

  local m_target_name=$(_get_post_backup_name $m_folder_to_check $m_count)
  do_folder_exist $m_target_name incremental_backup_if_file_exists rename_from_source $m_folder_to_check $((m_count+1))
}

incremental_backup_if_file_exists () {
  local m_file_to_check=$1
  local m_count=$2
  if [[ ( -z "$m_count" ) || ( "$m_count" == 0 ) ]] ; then
    m_count="0"
  fi

  rename_from_source () {
    local m_source_name=$(_get_pre_backup_name $1)
    local m_m_count=$2
    rename_bak_file $m_source_name $((m_m_count-1))
  }

  local m_target_name=$(_get_post_backup_name $m_file_to_check $m_count)
  do_file_exist $m_target_name incremental_backup_if_file_exists rename_from_source $m_file_to_check $((m_count+1))
}

git_clone_folder () {
  # Clone only a subfolder of a git repository
  # Git url can be either https://github.com/USERNAME/REPOSITORY or https://github.com/USERNAME/REPOSITORY.git
  # The function can not process other formats (e.g. /tree/BRANCH_NAME)
  local git_url=$1
  local folder_to_download=$2
  local target_branch=$3
  # regex to extract repository name
  local REGEX_GET_FOLDER='http.*[\/](.*?)(\.git)?\/?$'
  # apply regex
  [[ $git_url =~ $REGEX_GET_FOLDER ]]
  # match 0 is the string, 1 is the first match
  local git_main_folder=${BASH_REMATCH[1]%.git}
  if [ ! -z "${target_branch}" ]; then
    git clone \
      --depth 1  \
      -b $target_branch \
      --filter=blob:none  \
      --sparse \
      $git_url
  else
    git clone \
      --depth 1  \
      --filter=blob:none  \
      --sparse \
      $git_url
  fi
  cd $git_main_folder
  git sparse-checkout set $folder_to_download
  cd ..
}

get_date_string () {
  local curr_date=`date +"%Y%m%d_%H%M%S"`
  echo $curr_date
}

create_new_user () {
  # create new user with pww and generate ssh key
  local m_new_user=$1
  local m_new_password=$2
  echo "Creating $m_new_user user"
  sudo useradd -m -s /bin/bash $m_new_user
  echo $m_new_user:$m_new_password | sudo chpasswd -e
  echo "Generate ssh keys for user $m_new_user"
  sudo -H -u $m_new_user bash -c "ssh-keygen -t rsa -b 4096 -f /home/$m_new_user/.ssh/id_rsa -N ''"
}

get_missing_packages() {
  # mainly from https://stackoverflow.com/a/48615797
  # check if a list of packages is installed or not, return those that are not installed in a single string separated by a whitespace
  # simply run as `get_missing_packages nano git curl`
  local m_packages=$*
  echo $(dpkg --get-selections $m_packages 2>&1 | grep -v ' install$' | awk '{ print $6 }'  | tr '\n' ' '  | xargs)
}

install_missing_packages() {
  local m_packages=$*
  m_packages=`get_missing_packages $m_packages`
  if [ ! -z "$m_packages" ]; then
    sudo apt-get -q update 
    sudo apt install -y -q $m_packages
  fi
}

get_local_ip() {
  # from https://stackoverflow.com/a/25851186
  # get local ip of the main interface
  echo $(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')
}

get_main_interface() {
  # get main interface name
  local m_my_ip=$(get_local_ip)
  echo $(ifconfig | grep -B1 $m_my_ip | grep -o "^\w*")
}

add_vlan_interface() {
  # add a config file in /etc/network/interfaces.d/ called vlans
  # that adds the provided vlan interface to the main interface of the system
  # with dhcp address
  local m_main_if=$(get_main_interface)
  local m_vlan=$1 # number of the vlan subnet
  if [ -z "${m_vlan}" ]; then
    echo_red "Missing vlan number. Aborting."
    return
  fi
  sudo mkdir -p /etc/network/interfaces.d
  echo "" | sudo tee -a /etc/network/interfaces.d/vlan${m_vlan}.conf > /dev/null
  echo "auto ${m_main_if}.${m_vlan}" | sudo tee -a /etc/network/interfaces.d/vlan${m_vlan}.conf > /dev/null
  echo "  iface ${m_main_if}.${m_vlan} inet dhcp" | sudo tee -a /etc/network/interfaces.d/vlan${m_vlan}.conf > /dev/null
  echo "  vlan-raw-device ${m_main_if}" | sudo tee -a /etc/network/interfaces.d/vlan${m_vlan}.conf > /dev/null
  echo "" | sudo tee -a /etc/network/interfaces.d/vlan${m_vlan}.conf > /dev/null
  sudo systemctl restart networking
}


add_vlan_interface_netplan() {
  # for ubuntu > 18.04
  # add vlan to config file in /etc/netplan/10-vlan-config.yaml
  local m_main_if=$(get_main_interface)
  local m_vlan=$1 # number of the vlan subnet
  local m_subnet=$2 # subnet e.g. 192.168.1.0/24
  local m_gateway=$3
  local m_target_file="/etc/netplan/10-vlan-config.yaml"
  if [ -z "${m_gateway}" ]; then
    # default to subnet .1
    m_gateway=${m_gateway::-4}1
  fi
  # Do a backup
  enable_run_as_root
  incremental_backup_if_file_exists $m_target_file
  disable_run_as_root
  sudo cp /etc/netplan/10-vlan-config.yaml /etc/netplan/10-vlan-config.yaml.bak
  if [ -z "${m_vlan}" ]; then
    echo_red "Missing vlan number. Aborting."
    return
  fi
  m_append_network() {
    if ! grep -Fxq "network:" $m_target_file; then
      echo "network:" | sudo tee -a $m_target_file > /dev/null
    fi
  }
  m_create_file() {
    echo "network:" | sudo tee -a $m_target_file > /dev/null
  }
  do_file_exist $m_target_file m_append_network m_create_file
  if ! grep -Fxq "  vlans:" $m_target_file; then
    echo "  vlans:" | sudo tee -a $m_target_file > /dev/null
  fi
  echo """
    vlan.${m_vlan}:
        id: ${m_vlan}
        link: ${m_main_if}
        dhcp4: yes
        dhcp4-overrides:
          use-routes: false
        routes:
          - to: ${m_subnet}
            via: ${m_gateway}
            metric: 100
  """ | sudo tee -a $m_target_file > /dev/null
  sudo netplan apply
}


source_support_libs() {
  source <(curl -sL https://raw.githubusercontent.com/Kraktun/OpenScripts/main/linux/support/nginx.sh)
  source <(curl -sL https://raw.githubusercontent.com/Kraktun/OpenScripts/main/linux/support/utility.sh)
}


load_colors () {
  NO_COLOR='\033[0m'
  COLOR_BLACK='\033[0;30m'
  COLOR_RED='\033[0;31m'
  COLOR_GREEN='\033[0;32m'
  COLOR_YELLOW='\033[0;33m'
  COLOR_BLUE='\033[0;34m'
  COLOR_PURPLE='\033[0;35m'
  COLOR_CYAN='\033[0;36m'
  COLOR_WHITE='\033[0;37m'
}

echo_color () {
  load_colors
  local color=$1
  shift 1
  local s="$@"
  case $color in
    "black")
      local my_color=$COLOR_BLACK
      ;;
    "red")
      local my_color=$COLOR_RED
      ;;
    "green")
      local my_color=$COLOR_GREEN
      ;;
    "yellow")
      local my_color=$COLOR_YELLOW
      ;;
    "blue")
      local my_color=$COLOR_BLUE
      ;;
    "purple")
      local my_color=$COLOR_PURPLE
      ;;
    "cyan")
      local my_color=$COLOR_CYAN
      ;;
    "white")
      local my_color=$COLOR_WHITE
      ;;
    "nc")
      local my_color=$NO_COLOR
      ;;
    *)
      local my_color=$NO_COLOR
      ;;
  esac
  echo -e "${my_color}${s}${NO_COLOR}"
}

echo_black () {
  echo_color "black" "$*"
}
echo_red () {
  echo_color "red" "$*"
}
echo_green () {
  echo_color "green" "$*"
}
echo_yellow () {
  echo_color "yellow" "$*"
}
echo_blue () {
  echo_color "blue" "$*"
}
echo_purple () {
  echo_color "purple" "$*"
}
echo_cyan () {
  echo_color "cyan" "$*"
}
echo_white () {
  echo_color "white" "$*"
}
