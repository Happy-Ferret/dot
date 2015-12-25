# vim: ft=sh
dot_set() { 
  # option handling
  local linkfile l

  while getopts iv OPT
  do
    case $OPT in
      "i" ) dotset_interactive=false ;;
      "v" ) dotset_verbose=true ;;
    esac
  done


  check_dir() { #{{{
    local orig="$1"

    origdir="${orig%/*}"

    [ -d "${origdir}" ] && return 0

    echo -n "[$(tput bold)$(tput setaf 1)error$(tput sgr0)] "
    echo "$(tput bold)${origdir}$(tput sgr0) doesn't exist."

    ${dotset_interactive} || return 0

    echo -n "make directory $(tput bold)${origdir}$(tput sgr0)? (Y/n):"
    read confirm
    if [ "$confirm" != "n" ]; then
      mkdir -p "${origdir}" &&
      return 0
    else
      echo "Aborted."
      return 1
    fi
  } #}}}


  if_islink() { #{{{
    local orig="$1"
    local dotfile="$2"
    local linkto="$(readlink "${orig}")"
    local yn

    # if the link has already be set: do nothing
    if [ "${linkto}" = "${dotfile}" ]; then
      ${dotset_verbose} &&
        echo "[$(tput bold)$(tput setaf 2)done$(tput sgr0)] ${orig}"
      return 0
    fi

    echo -n "[$(tput bold)$(tput setaf 1)conflict$(tput sgr0)] "
    echo "Other link already exists at $(tput bold)${orig}$(tput sgr0)"

    ${dotset_interactive} || return 0

    echo -n "  [$(tput bold)$(tput setaf 3)try$(tput sgr0)] "
    echo "${orig} $(tput bold)$(tput setaf 5)<--$(tput sgr0) ${dotfile}"
    echo -n "  [$(tput bold)$(tput setaf 2)now$(tput sgr0)] "
    echo "${orig} $(tput bold)$(tput setaf 5)<--$(tput sgr0) ${linkto}"
    echo "Unlink and re-link for $(tput bold)${orig}$(tput sgr0)? (y/n)"
    while echo -n ">>> "; read yn; do
      case $yn in
        [Yy] )
          unlink "${orig}"
          ln -s "${dotfile}" "${orig}"
          echo -n "[$(tput bold)$(tput setaf 2)done$(tput sgr0)] "
          echo "${orig}"
          break
          ;;
        [Nn] )
          break
          ;;
        * )
          echo "Please answer with y or n."
          ;;
      esac
    done

    return 0
  } #}}}


  if_exist() { #{{{
    local line
    local orig="$1"
    local dotfile="$2"

    if ! ${dotset_interactive}; then
      echo -n "[$(tput bold)$(tput setaf 1)conflict$(tput sgr0)] "
      echo "File already exists at $(tput bold)${orig}$(tput sgr0)."
      return 0
    fi

    while true; do
      echo -n "[$(tput bold)$(tput setaf 1)conflict$(tput sgr0)] "
      echo "File already exists at $(tput bold)${orig}$(tput sgr0)."
      echo "Choose the operation."
      echo "    ($(tput bold)d$(tput sgr0)):show diff"
      echo "    ($(tput bold)e$(tput sgr0)):edit files"
      echo "    ($(tput bold)f$(tput sgr0)):replace"
      echo "    ($(tput bold)b$(tput sgr0)):replace and make backup"
      echo "    ($(tput bold)n$(tput sgr0)):do nothing"
      echo -n ">>> "; read line
      case $line in
        [Dd] )
          eval "${diffcmd}" "${dotfile}" "${orig}"
          echo ""
          ;;
        [Ee] )
          eval "${edit2filecmd}" "${dotfile}" "${orig}"
          ;;
        [Ff] )
          if [ -d "${orig}" ]; then
            rm -r -- "${orig}"
          else
            rm -- "${orig}"
          fi
          ln -s "${dotfile}" "${orig}"
          echo -n "[$(tput bold)$(tput setaf 2)done$(tput sgr0)] "
          echo "${orig}"
          break
          ;;
        [Bb] )
          ln -sb --suffix '.bak' "${dotfile}" "${orig}"
          echo -n "[$(tput bold)$(tput setaf 2)done$(tput sgr0)] "
          echo "${orig}"
          echo -n "[$(tput bold)$(tput setaf 2)make backup$(tput sgr0)] "
          echo "${orig}.bak"
          break
          ;;
        [Nn] )
          break
          ;;
        *)
          echo "Please answer with [d/e/f/b/n]."
          ;;
      esac
    done

    return 0
  } #}}}


  _dot_set() { #{{{
    local dotfile orig
    # extract environment variables
    dotfile="$(eval echo $1)"
    orig="$(eval echo $2)"

    # path completion
    [ "${dotfile:0:1}" = "/" ] || dotfile="${dotdir}/$dotfile"
    [ "${orig:0:1}" = "/" ] || orig="$HOME/$orig"

    # if dotfile doesn't exist, print error message and pass
    if [ ! -e "${dotfile}" ]; then
      echo "[$(tput bold)$(tput setaf 1)not found$(tput sgr0)] ${dotfile}"
      return 1
    fi

    # if the targeted directory doesn't exist,
    # ask whether make directory or not.
    check_dir "${orig}" || return 1

    if [ -e "${orig}" ]; then                 # if the file already exists:
      if [ -L "${orig}" ]; then               #   if it is a symbolic-link:
        if_islink "${orig}" "${dotfile}"      #      do nothing or relink
      else                                    #   if it is a file or a dir:
        if_exist "${orig}" "${dotfile}"       #      ask user what to do
      fi                                      #
    else                                      # else:
      ln -s "${dotfile}" "${orig}"            #   make symbolic link
      if ${dotset_verbose}; then
        echo -n "[$(tput bold)$(tput setaf 2)done$(tput sgr0)] "
        echo "${orig}"
      fi
    fi

  } #}}}


  for linkfile in "${linkfiles[@]}"; do
    echo "$(tput bold)$(tput setaf 4)Loading ${linkfile} ...$(tput sgr0)"
    for l in $(grep -Ev '^#|^$' "${linkfile}"); do
      _dot_set $(echo $l | tr ',' ' ')
    done
  done

  unset -f check_dir if_islink if_exist _dot_set $0

} 
