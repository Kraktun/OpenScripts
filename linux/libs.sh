#!/bin/bash

# Beware: currently I'm reusing variables in recursive calls, so if you run functions with as arguments
# other functions of this script you may get weird/wrong results.
# Also, don't expect for things to work deterministically. Sometimes I don't know what I'm doing.

# Note: for the functions you pass as arguments, if you want to exit the script, use `exit`, not `return` or it just returns from the function.


check_folder_exist () {
  # check if any folder passed as parameter exists.
  # Return 0 if it doesn't, 1 otherwise.
  # Yes, ugly, but it's like this for compatibility with old stuff that I wrote.

  # example usage
  #   check_folder_exist /path/to/my/folder
  local folder_to_check=$1
  if [ ! -d "$folder_to_check" ]; then
    echo "0" # does not exist
  else
    echo "1" # exists
  fi
}

do_folder_exist () {
  # execute a command or function if the provided folder exists
  
  # example usage
  #   echo_exists(){
  #     echo "Folder exists. Passed arg is $1"    
  #   }
  #   echo_doesnt_exist(){
  #     echo "Folder doesn't exist. Passed arg is $1"    
  #   }
  #   do_folder_exist /path/to/my/folder echo_exists echo_doesnt_exist "optional_argument"
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

check_file_exist () {
  # check if any folder passed as parameter exists.
  # Return 0 if it doesn't, 1 otherwise

  # example usage
  #   check_file_exist /path/to/my/file.txt
  local file_to_check=$1
  if [ ! -e "$file_to_check" ]; then
    echo "0" # does not exist
  else
    echo "1" # exists
  fi
}

do_file_exist () {
  # execute a command or function if the provided file exists

  # example usage: see do_folder_exist
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
  # Execute a function if a variable exists

  # example usage
  #   echo_exists(){
  #     echo "Variable exists. Passed arg is $1"    
  #   }
  #   echo_doesnt_exist(){
  #     echo "Variable doesn't exist. Passed arg is $1"    
  #   }
  #   MY_SUPER_VAR=ciao
  #   do_variable_exist MY_SUPER_VAR echo_exists echo_doesnt_exist "optional_argument"
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
  # Similar to do_variable_exist, but here we check that the variable is non empty. Note that this works only if the variable is set.
  # Use do_variable_exist_non_empty if you are not sure if the variable exists.
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
  # Similar to do_variable_exist but also checks that the variable is not empty.
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
  # Execute functions if the current script has been sourced or not.
  # You need to specify the source level, i.e. which is the script you want to know if it was sourced.
  # Levels start from 0.
  # If for instance you have a script that calls `source libs.sh` and want to know if that script was itself sourced, you need to use level 1.
  # If you copy this function to your own script and want to know if your script is being sourced, then use level 0.

  # example usage
  #   do_sourced_file 1 script_was_sourced_func script_was_not_sourced_func optional args
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

get_group_id () {
  # Return the id of a group

  # example usage
  #   my_var=`get_group_id my_group_name`
  local group_name=$1
  local gr_id=`getent group $group_name | cut -d: -f3`
  echo $gr_id
}

ask_yes_no_function () {
  # Print a message asking y/n and execute functions depending on the answer.

  # example usage
  #   ask_yes_no_function "Do you want to proceed?" yes_function no_function optional args
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
  # This function just waits a bit. Can't be 0 or it is skipped all together.
  sleep 0.01
}

enable_color_prompt () {
  # Enable the color prompt in most debian based systems.
  # If you want to enable it for a different user from the one that is calling the function, you need to call `enable_run_as_root`` first.

  # example usage
  #   enable_color_prompt $USER
  local m_user=$1
  maybe_run_as_root sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/' /home/$m_user/.bashrc
}

disable_home_share () {
  # Sets the permission for the new users folders in /home/*.
  # Also set the same permission to the ones already present.
  # The permission disables rx access to 'other'.

  if [[ $(is_run_as_root) ]]; then 
    incremental_backup_if_file_exists /etc/adduser.conf
  else
    enable_run_as_root
    incremental_backup_if_file_exists /etc/adduser.conf
    disable_run_as_root
  fi
  sudo sed -i 's/DIR_MODE=0755/DIR_MODE=0750/' /etc/adduser.conf
  sudo find /home -maxdepth 1 -mindepth 1 -type d -exec chmod 750 {} \;
}

_run_as_root () {
  # Run the passed function as root. The passed argument must be either a command or a top level function.
  # Top level function = a function that does not execute other functions, but only commands.
  
  local m_func_name=$1
  shift
  local m_args=$*
  # contains the content of the function, empty if it's a command
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
  # Execute the following functions that may require root as root.
  M_RUN_AS_ROOT_K=1
}

disable_run_as_root () {
  # Disable root for the following functions.
  unset M_RUN_AS_ROOT_K
}

is_run_as_root () {
  # Check if run as root is enabled

  # example usage
  # if [[ $(is_run_as_root) ]]; then
  #   echo "Yes"
  # fi
  echo_true () {
    echo 1
  }
  do_variable_exist_non_empty M_RUN_AS_ROOT_K echo_true do_nothing_function
}

maybe_run_as_root () {
  # Execute the passed top level function or command as root only if enable_run_as_root was called.
  # Execute as your user if enable_run_as_root was not called or disable_run_as_root was called after it.

  # example usage
  #   maybe_run_as_root my_top_level_function optional arguments
  # or
  #   enable_run_as_root
  #   maybe_run_as_root systemctl enable nginx
  #   disable_run_as_root
  local m_func_name=$1
  shift
  m_run_as_root_explicit_func () {
    _run_as_root $m_func_name $@
  }
  if [[ $(is_run_as_root) ]]; then
    m_run_as_root_explicit_func $@
  else
    $m_func_name $@
  fi
}

_get_pre_backup_name () {
  # Return the original name of the file we want to backup, i.e. the file without the suffix .bakN (with N any number, also no number)
  # For reference
  # https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html#Shell-Parameter-Expansion
  # https://www.gnu.org/software/bash/manual/html_node/Pattern-Matching.html

  local m_file=$1
  echo "${m_file%.bak*([0-9])}"
}

_get_post_backup_name () {
  # Return the backup name with the provided counter as $original_filename.bak$counter

  local m_file=$1
  local m_counter=$2
  if [[ ( -z "$m_counter" ) || ( "$m_counter" == 0 ) ]] ; then
    m_counter=""
  fi
  echo "${m_file}.bak${m_counter}"
}
 
_rename_bak_file () {
  # Make a backup copy of the provided file with the specified backup counter.
  # _rename_bak_file /path/to/file/to/rename.txt 2
  local m_out_name=$(_get_post_backup_name $1 $2)
  maybe_run_as_root cp -r "$1" "$m_out_name"
}

incremental_backup_if_folder_exists () {
  # Create a copy of the provided folder by appending .bakN with N an increasing number starting from 0.
  # If a folder with suffix .bakN is already present, the latest digit (N) will be recursively incremented.
  # The initial number can be omitted.

  # example usage
  #   incremental_backup_if_folder_exists /path/to/folder
  local m_folder_to_check=$1
  local m_count=$2
  if [[ ( -z "$m_count" ) || ( "$m_count" == 0 ) ]] ; then
    m_count="0"
  fi

  rename_from_source () {
    local m_source_name=$(_get_pre_backup_name $1)
    local m_m_count=$2
    _rename_bak_file $m_source_name $((m_m_count-1))
  }

  local m_target_name=$(_get_post_backup_name $m_folder_to_check $m_count)
  do_folder_exist $m_target_name incremental_backup_if_folder_exists rename_from_source $m_folder_to_check $((m_count+1))
}

date_backup_if_exists () {
  # Create a copy of the provided folder\file by appending .bak_$date where date has format %Y%m%d_%H%M%S

  # example usage
  #   date_backup_if_exists /path/to/folder
  local m_source_name=$1
  local m_date=_$(get_date_string)
  _rename_bak_file $m_source_name $m_date
}

incremental_backup_if_file_exists () {
  # Create a copy of the provided file by appending .bakN with N an increasing number starting from 0.
  # If a file with suffix .bakN is already present, the latest digit (N) will be recursively incremented.
  # The initial number can be omitted.

  # example usage
  #   incremental_backup_if_file_exists /path/to/file.txt
  local m_file_to_check=$1
  local m_count=$2
  if [[ ( -z "$m_count" ) || ( "$m_count" == 0 ) ]] ; then
    m_count="0"
  fi

  rename_from_source () {
    local m_source_name=$(_get_pre_backup_name $1)
    local m_m_count=$2
    _rename_bak_file $m_source_name $((m_m_count-1))
  }

  local m_target_name=$(_get_post_backup_name $m_file_to_check $m_count)
  do_file_exist $m_target_name incremental_backup_if_file_exists rename_from_source $m_file_to_check $((m_count+1))
}

git_clone_folder () {
  # Clone only a subfolder of a git repository in this folder. Note that the structure of the repo is preserved (i.e. it will always create a folder with the name of the repo)
  # Git url can be either https://github.com/USERNAME/REPOSITORY or https://github.com/USERNAME/REPOSITORY.git
  # The function can not process other formats (e.g. /tree/BRANCH_NAME)

  # example usage
  #   git_clone_folder https://github.com/Kraktun/OpenScripts linux
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
  # Get current date in the format %Y%m%d_%H%M%S

  # example usage
  #   my_var=$(get_date_string)
  local curr_date=`date +"%Y%m%d_%H%M%S"`
  echo $curr_date
}

create_new_user () {
  # create a new user with the provided (hashed) password and generate ssh key

  # example usage
  #   create_new_user pippo '$1$ks/H3N$dsnh3nGeKwm9B/'
  local m_new_user=$1
  local m_new_password=$2
  echo "Creating $m_new_user user"
  sudo useradd -m -s /bin/bash $m_new_user
  echo $m_new_user:$m_new_password | sudo chpasswd -e
  echo "Generate ssh keys for user $m_new_user"
  sudo -H -u $m_new_user bash -c "ssh-keygen -t rsa -b 4096 -f /home/$m_new_user/.ssh/id_rsa -N ''"
}

get_missing_packages() {
  # Mainly from https://stackoverflow.com/a/48615797
  # check if a list of packages is installed or not, return those that are not installed in a single string separated by a whitespace.
  # For debian based distros.

  # example usage
  #   my_missing_packages=$(get_missing_packages nano git curl)
  local m_packages=$*
  echo $(dpkg --get-selections $m_packages 2>&1 | grep -v ' install$' | awk '{ print $6 }'  | tr '\n' ' '  | xargs)
}

install_missing_packages() {
  # Install only the missing packages from a list of provided packages.
  # For debian based distros.

  # example usage
  #   install_missing_packages git curl nginx
  local m_packages=$*
  m_packages=`get_missing_packages $m_packages`
  if [ ! -z "$m_packages" ]; then
    sudo apt-get -q update 
    sudo apt install -y -q $m_packages
  fi
}

get_local_ip() {
  # From https://stackoverflow.com/a/25851186
  # get the local ip of the main interface

  # example usage
  #   my_ip=`get_local_ip`
  echo $(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')
}

get_main_interface() {
  # Get main interface name

  # example usage
  #   my_if=`get_main_interface`
  local m_my_ip=$(get_local_ip)
  echo $(ifconfig | grep -B1 $m_my_ip | grep -o "^\w*")
}

add_vlan_interface() {
  # Add a config file in /etc/network/interfaces.d/ called vlans
  # that adds the provided vlan interface to the main interface of the system
  # with dhcp address
  # NOTE: REQUIRES net-tools PACKAGE

  # example usage
  #   add_vlan_interface 5
  local m_main_if=$(get_main_interface)
  local m_vlan=$1 # number of the vlan subnet, e.g. 1, 2, 3, 120
  if [ -z "${m_vlan}" ]; then
    echo_red "Missing vlan number. Aborting."
    return
  fi
  local m_target_file="/etc/network/interfaces.d/vlan${m_vlan}.conf"
  if [[ $(is_run_as_root) ]]; then
    incremental_backup_if_file_exists $m_target_file
  else
    enable_run_as_root
    incremental_backup_if_file_exists $m_target_file
    disable_run_as_root
  fi
  sudo mkdir -p /etc/network/interfaces.d
  echo """
auto ${m_main_if}.${m_vlan}
  iface ${m_main_if}.${m_vlan} inet dhcp
  vlan-raw-device ${m_main_if}
  """ | sudo tee -a $m_target_file > /dev/null
  sudo systemctl restart networking
}

add_vlan_interface_network_manager() {
  # Add a vlan interface to armbian (maybe other debian distros)

  # example usage
  #   add_vlan_interface 5
  local m_main_if=$(get_main_interface)
  local m_vlan=$1 # number of the vlan subnet
  sudo nmcli con add type vlan con-name VLAN$m_vlan dev $m_main_if id $m_vlan
  sudo nmcli connection up VLAN$m_vlan
}


add_vlan_interface_netplan() {
  # add vlan to config file in /etc/netplan/10-vlan-config.yaml
  # For ubuntu > 18.04

  # example usage
  #   add_vlan_interface 5 '192.168.5.0/24' 192.168.5.1
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
  if [[ $(is_run_as_root) ]]; then
    incremental_backup_if_file_exists $m_target_file
  else
    enable_run_as_root
    incremental_backup_if_file_exists $m_target_file
    disable_run_as_root
  fi
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

wait_for_connection () {
  # Wait for connection to be up, either a server or a generic url with user defined timeout (seconds).

  # example usage
  #   return_code=$(wait_for_connection google.com 30)
  # or
  #   return_code=$(wait_for_connection 192.168.0.10 30)
  local m_url=$1
  local m_timeout=$2
  local m_counter=0
  until ping -q -w 1 -c 1 $m_url > /dev/null || [[ $m_counter -ge $m_timeout ]]
  do
    sleep 1
    m_counter=$((m_counter + 1))
  done

  if [[ $m_counter -ge $m_timeout ]]; then
    return 1
  fi
}


source_support_libs() {
  source <(curl -sL https://raw.githubusercontent.com/Kraktun/OpenScripts/main/linux/support/nginx.sh)
  source <(curl -sL https://raw.githubusercontent.com/Kraktun/OpenScripts/main/linux/support/utility.sh)
}


_load_colors () {
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

_echo_color () {
  _load_colors
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
  _echo_color "black" "$*"
}
echo_red () {
  # example usage
  #   echo_black hello I'll be printed in red
  _echo_color "red" "$*"
}
echo_green () {
  _echo_color "green" "$*"
}
echo_yellow () {
  _echo_color "yellow" "$*"
}
echo_blue () {
  _echo_color "blue" "$*"
}
echo_purple () {
  _echo_color "purple" "$*"
}
echo_cyan () {
  _echo_color "cyan" "$*"
}
echo_white () {
  _echo_color "white" "$*"
}
