#!/bin/bash


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
  read -p "$message [y/n]" -r
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
  sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/' /home/$user/.bashrc
}

disable_home_share () {
  sed -i 's/DIR_MODE=0755/DIR_MODE=0750/' /etc/adduser.conf
}

rename_bak_file() {
  local file_to_rename=$1
  mv "$file_to_rename" "${file_to_rename}.bak"
}

backup_if_folder_exists () {
  local folder_to_check=$1
  do_folder_exist $folder_to_check rename_bak_file do_nothing_function $folder_to_check
}

backup_if_file_exists () {
  local file_to_check=$1
  do_file_exist $file_to_check rename_bak_file do_nothing_function $file_to_check
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
  echo_color "black" $*
}
echo_red () {
  echo_color "red" $*
}
echo_green () {
  echo_color "green" $*
}
echo_yellow () {
  echo_color "yellow" $*
}
echo_blue () {
  echo_color "blue" $*
}
echo_purple () {
  echo_color "purple" $*
}
echo_cyan () {
  echo_color "cyan" $*
}
echo_white () {
  echo_color "white" $*
}
