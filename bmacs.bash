#!/bin/bash
#
# bmacs - bogus again
#

#
# THIS IS A JOKE.
#
# (not a very funny one, either)

doc()
{
  func[$max_func]="$1"
  documentation[$max_func]="$2"
  max_func=$[max_func + 1]
}

###########################################################################
# Screen drawing functions
###########################################################################

draw_modeline()
{
  local mod
  if [ $modified = 1 ]; then
    mod="*"
  else
    mod="-"
  fi

  local ro
  if [ $read_only = 1 ]; then
    ro="%"
  else
    ro="$mod"
  fi

  local percent="[$col $line] ($x $y) $lines"	# @@@

  # Modeline format
  local modeline_template
  if [ "x$modeline_format" = x ] ; then
    modeline_template="$default_modeline_format"
  else
    modeline_template="$modeline_format"
  fi

  local i=0
  local c
  local expanded_modeline
  while [ $i -lt ${#modeline_template} ]
  do
    c=${modeline_template:$i:1}
    if [ "$c" = '%' ] ; then
      i=$[i + 1]
      c=${modeline_template:$i:1}
      case "$c" in
	\*)	expanded_modeline="${expanded_modeline}${mod}"		;;
	\+)	expanded_modeline="${expanded_modeline}${ro}"		;;
	h)	expanded_modeline="${expanded_modeline}${host}"		;;
	b)	expanded_modeline="${expanded_modeline}${buf_name}"	;;
	m)	expanded_modeline="${expanded_modeline}${mode[*]}"	;;
	p)	expanded_modeline="${expanded_modeline}${percent}"	;;
	-)
	  local dash_len=$[screen_cols - ${#expanded_modeline}]
	  local blanks=$(printf "%${dash_len}s" ' ')
	  local dashes=${blanks// /-}
	  expanded_modeline="${expanded_modeline}${dashes}"
	  ;;
      esac
    else
      expanded_modeline="${expanded_modeline}${c}"
    fi
    i=$[i + 1]
  done

  moveto $win_height 0	# goto the bottom of the window
  echo -n "$t_sgr0"
  if [ $has_color = 1 ] ; then
    bg_blue
    fg_green
  fi
  echo -n "${expanded_modeline}${t_sgr0}"
}

doc toggle-update-modeline "Toggle updating the modeline."
toggle-update-modeline()
{
  debug "$FUNCNAME"
  update_modeline=$[! update_modeline]
}

doc toggle-debug "Toggle debugging."
toggle-debug()
{
  debug "$FUNCNAME"
  debug_flag=$[! debug_flag]
}

doc toggle-line-numbers "Toggle displaying line numbers."
toggle-line-numbers()
{
  debug "$FUNCNAME"
  line_numbers=$[! line_numbers]
}

line_view_len()
{
  declare -i bi=${bix[$1]}
  local l="${buf[$bi]}"
  line_view_col $1 ${#l}
  return $?
}

line_view_col()
{
  local ln=$1			# the line
  local cl=$2			# target col
  declare -i bi=${bix[$ln]}
  local l="${buf[$bi]}"
  local s="${l//	}"	# Check for any tab
  if [ ${#l} -eq ${#s} ]; then
    return $cl
  fi
  local len=${#l}
  local total=0
  local i=0
  while [ $i -lt $len -a $i -lt $cl ]
  do
    if [ "${l:$i:1}" = '	' ]; then
      total=$[total + (8 - (total % 8))]
    else
      total=$[total + 1]
    fi
    i=$[i + 1]
  done
  return $total
}

old_line_view_col()
{
  local ln=$1
  local cl=$1
  declare -i bi=${bix[$ln]}
  local l="${buf[$bi]}"
  local s="${l//	}"
  if [ ${#l} -eq ${#s} ]; then
    return ${#buf[$bi]}
  fi

  local len=${#s}
  local total=0
  local tt
  while [ $len != 0 ]
  do
    # output consecutive tabs
    while [ "${l:0:1}" = '	' ]
    do
      tt=$[8 - (total % 8)]
      l="${l/?([	])/}"	# snip off one tab
      total=$[total + $tt]
    done

    s="${l/+([	]*)/}"	# beginning without tabs
    len=${#s}

    if [ ${#s} -ne ${#l} ]; then
      total=$[total + len]
      tt=$[8 - (total % 8)]
      total=$[total + tt]
    else			# no more tabs
      total=$[total + ${#l}]
      return $total
    fi

    l="${l##+([^	])}"	# the rest
    l="${l/?([	])/}"		# snip off one tab

  done
  shopt -u extglob
  return $total
}

# render a line with tabs
render_line()
{
  shopt -s extglob
  local l="$*"
  local s="${l//	}"

  # no tabs in the line
  if [ ${#l} -eq ${#s} ]; then
    if [ "$colorizer" ]; then
      $colorizer "$l"
      l="$syntax_line"
    fi
    echo -n "$l"
    return
  fi

#  s="${l/+([	]*)/}"	# beginning without tabs
  local len=${#s}
  local total=0
  local tt=0
  local fixed_line=""

#  printf ".......T.......T.......T.......T.......T\n"
#  fg_red
  while [ $len != 0 ]
  do
    # output consecutive tabs
    while [ "${l:0:1}" = '	' ]
    do
      tt=$[8 - (total % 8)]
      fixed_line="$fixed_line""$(printf '%*.*s' $tt $tt '        ')"
      l="${l/?([	])/}"	# snip off one tab
      total=$[total + $tt]
    done

    s="${l/+([	]*)/}"	# beginning without tabs
    len=${#s}

    if [ ${#s} -ne ${#l} ]; then
      total=$[total + len]
      tt=$[8 - (total % 8)]
#      echo "tt=$tt s=$s"
      fixed_line="$fixed_line""$(printf '%s%*.*s' "$s" $tt $tt '        ')"
      total=$[total + tt]
    else
#      echo -n "$l"
      fixed_line="$fixed_line""$l"
      if [ "$colorizer" ]; then
	$colorizer "$fixed_line"
	fixed_line="$syntax_line"
      fi
      echo -n "$fixed_line"
#      fg_green
      return
    fi

    l="${l##+([^	])}"	# the rest
    l="${l/?([	])/}"		# snip off one tab
  done

  if [ "$colorizer" ]; then
    $colorizer "$fixed_line"
    fixed_line="$syntax_line"
  fi
  echo -n "$fixed_line"
  shopt -u extglob
#  fg_green
}

## redraw the given screen line
redraw_line()
{
  moveto $1 0
  echo -n "${t_sgr0}${t_rmir}${t_el}"	# no attr, no insert, erase line
  declare -i l=$[win_start + $1]
  declare -i bi=${bix[$l]}
  if [ "${buf[$bi]}" ]; then
#    echo -n "${buf[$bi]:0:$screen_cols}"
    render_line "${buf[$bi]:0:$screen_cols}"
  fi
  echo -n "$t_enter_insert_mode"	# insert mode on
}

redraw()
{
  if [ $line_to_redraw != x ]; then
    redraw_line "$line_to_redraw"
    moveto $y $x			# go back to the cursor location
    line_to_redraw=x
    need_to_redraw=0
    return
  fi

  # clear, no attributes, insert mode off
  tput csr 0 $screen_rows
  echo -n "${t_sgr0}${t_rmir}${t_clear}"

  # display the lines in the buffer
  local i=$win_start
  local win_end=$[win_start + (win_height - 1)]
  declare -i bi
  declare -i j=0
  while [ $i -lt $win_end -a $i -lt $lines ]; do
    bi=${bix[$i]}

    if [ $line_numbers = 1 ]; then
      moveto $j 76 ; fg_blue ; printf "%3d " $bi ; fg_green ; moveto $j 0
#        line_view_len $i ; lnln=$?
#        moveto $j 76 ; fg_blue ; printf "%3d " $lnln ; fg_green ; moveto $j 0
    fi

    if [ "${buf[$bi]}" ]; then
#      printf "%-${screen_cols}.${screen_cols}s\n" "${buf[$bi]}"
#      echo "${buf[$bi]:0:$screen_cols}"
      render_line "${buf[$bi]:0:$screen_cols}"
      echo
    else
      echo
    fi
    i=$[i + 1]
    j=$[j + 1]
  done

  # can't put a newline on the last one, because of the scrolling region
  if [ $i = $win_end ]; then
    bi=${bix[$i]}
    if [ "${buf[$bi]}" ]; then
#      echo -n "${buf[$bi]:0:$screen_cols}"
      render_line "${buf[$bi]:0:$screen_cols}"
    fi
  fi

  draw_modeline
  tput csr 0 $[win_height - 1]
  moveto $y $x				# goto the cursor location
  echo -n "$t_enter_insert_mode"	# insert mode on

  need_to_redraw=0
}

typeout()
{
  bg_green
  fg_black
  echo -n "${t_rmir}"
  local wid=$[screen_cols - 10]

  eval "$1" | (
    local nana
    local i=2
    while read nana
    do
      moveto $i 5
      printf "%-${wid}.${wid}s\n" "$nana"
      i=$[i + 1]
    done
    moveto $i 5
  )
  printf "%-${wid}.${wid}s\n" " "
  tput cuf 5
  printf "%-${wid}.${wid}s" "---Press the ANY key to continue---"
  read -sr -d '' -n 1

  bg_black
  fg_green
  echo -n "${t_enter_insert_mode}"

  need_to_redraw=1
}

get_screen_size()
{
  local sizes=$($stty size)
  if [ $? = 0 ] ; then
    set $sizes
    screen_rows="$1"
    screen_cols="$2"
  fi
  debug "screen_rows=$1 screen_cols=$2"
}

init_term_vars()
{
  # Screen size
  screen_cols=80
  screen_rows=24
  get_screen_size

  # Color
  if [ "$(tput colors 2> /dev/null)" -ge 8 ] ; then
    has_color=1
  else
    has_color=0
  fi

  # Bells
  t_bell=$(tput bel 2>/dev/null)
  t_flash=$(tput flash 2>/dev/null)
  if [ "x$t_bell" = x ]; then 
    t_bell=""
  fi
  if [ "x$t_flash" = x ] ; then
    t_flash=$t_bell
  fi

  # Movement
  t_cuf1=$(tput cuf1 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking cuf1."
  fi
  t_cub1=$(tput cub1 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking cub1."
  fi
  t_cud1="$(tput cud1 2>/dev/null)"
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking cud1."
  fi
  t_cuu1=$(tput cuu1 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking cuu1."
  fi

  # Alteration
  t_dch1=$(tput dch1 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking dch1."
  fi
  t_clear=$(tput clear 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking clear."
  fi
  t_el=$(tput el 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking el."
  fi
  t_il1=$(tput il1 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking il1."
  fi
  t_dl1=$(tput dl1 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking dl1."
  fi

  # Modes
  t_enter_insert_mode=$(tput smir 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. \
Lacking enter_insert_mode."
  fi
  t_rmir=$(tput rmir 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking rmir."
  fi
  t_sgr0=$(tput sgr0 2>/dev/null)
  if [ $? != 0 ] ; then
    fatal "Terminal description is not fully functional. Lacking sgr0."
  fi

}

# for speed
moveto()
{
  echo -ne '\033['$[$1 + 1]';'$[$2 + 1]'H'
  # tput cup $1 $2
}

# for speed
fg_black()   { echo -ne '\033[30m' ; } # tput setaf 0
fg_red()     { echo -ne '\033[31m' ; } # tput setaf 1
fg_green()   { echo -ne '\033[32m' ; } # tput setaf 2
fg_yellow()  { echo -ne '\033[33m' ; } # tput setaf 3
fg_blue()    { echo -ne '\033[34m' ; } # tput setaf 4
fg_magenta() { echo -ne '\033[35m' ; } # tput setaf 5
fg_cyan()    { echo -ne '\033[36m' ; } # tput setaf 6
fg_white()   { echo -ne '\033[37m' ; } # tput setaf 7

bg_black()   { echo -ne '\033[40m' ; } # tput setaf 0
bg_red()     { echo -ne '\033[41m' ; } # tput setaf 1
bg_green()   { echo -ne '\033[42m' ; } # tput setaf 2
bg_yellow()  { echo -ne '\033[43m' ; } # tput setaf 3
bg_blue()    { echo -ne '\033[44m' ; } # tput setaf 4
bg_magenta() { echo -ne '\033[45m' ; } # tput setaf 5
bg_cyan()    { echo -ne '\033[46m' ; } # tput setaf 6
bg_white()   { echo -ne '\033[47m' ; } # tput setaf 7

init_term()
{
  saved_tty_modes=$(stty -g)
  stty -echo
  stty susp '^-'
#  stty intr '^-'
#  stty intr '^g'
#  tput init
  tput is1
  echo -n "$t_enter_insert_mode"
  tput csr 0 $[win_height - 1]
}

reset_term()
{
  stty echo
  stty "$saved_tty_modes"
  tput rmir

  # This can screw up xterms
  #  tput reset
  # so instead do:
  tput csr 0 $screen_rows
  tput sgr0
}

message()
{
  moveto $screen_rows 0
  echo -n "$t_el"
  echo -n "$@"
  moveto $y $x
}

prompt()
{
  tput csr 0 $screen_rows
  moveto $screen_rows 0
  echo -n "${t_el}${t_rmir}"
  stty echo -opost
  read -e -p "$@" response
  local stat=$?
  stty -echo opost
  echo -n "${t_enter_insert_mode}"
  tput csr 0 $[win_height - 1]
  return $stat
}

minibuf-self-insert()
{
  echo -n "$c"
  response="${response}${c}"
}

minibuf-accept()
{
  minibuf_done_flag=1
}

minibuf-abort()
{
  minibuf_done_flag=1
  minibuf_abort_flag=1
}

new_prompt()
{
  local saved_x=$x
  local saved_y=$y

  moveto $screen_rows 0
  echo -n "${t_el}${t_rmir}"
  echo -n "$@"

  minibuf_done_flag=0
  minibuf_abort_flag=0
  response=""

  until [ $minibuf_done_flag = 1 ]; do
    IFS=: read -sr -d '' -n 1 c
    if [ $? != 0 ]; then
      # eof, error or timeout
      :
    fi
    char_to_int "$c"
    key=$?
    if [ ! -z ${mini_map[$key]} ]; then
      t=$(type -t ${global_map[$key]})
      if [ ! -z "$t" ] ; then
	if [ "$t" = 'function' ]; then
	  ${mini_map[$key]}
	else
	  case "$t" in
	    alias|keyword|builtin) ${mini_map[$key]}  ;;
	  esac
	fi
      fi
    fi
  done
  local stat=0

  moveto $screen_rows 0
  echo -n "$t_el"
  echo -n "${t_enter_insert_mode}"

  if [ $minibuf_abort_flag = 1 ]; then
    response=""
    stat=1
    echo -n "Aborted."
  fi

  moveto $saved_y $saved_x

  return $stat
}

ring_bell()
{
  if [ $visible_bell = 1 ] ; then
    echo -n $t_flash
  else
    echo -n $t_bell
  fi
}

# Save buffer position, eval each arg, and restore position.
# Returns the last result.
save_excursion()
{
  local o_x=$x
  local o_y=$y
  local o_col=$col
  local o_line=$line
  local o_do_update=$do_update
  set_update 0

  local stat=0
  for z in "$@"
  do
    eval "$z"			# oh the crapness
    stat=$?
  done

  x=$o_x
  y=$o_y
  col=$o_col
  line=$o_line
  set_update $o_do_update
  
  return $stat
}

set_update()
{
  if [ $1 = 0 ]; then
    if [ $do_update != 0 ]; then
      no_update=1
      update_off
    fi
  else
    if [ $do_update != 0 ]; then
      no_update=0
      update_on
    fi
  fi
}

update_off()
{
  echo()
  {
    :
  }
  printf()
  {
    :
  }
  tput()
  {
    :
  }
}

update_on()
{
  unset echo
  unset printf
  unset tput
}

###########################################################################
# Variables and initialization
#

save_buf_vars()
{
  eval "${buf_name}_modified=$modified"
  eval "${buf_name}_read_only=$read_only"
  eval "${buf_name}_buf_name=$buf_name"
  eval "${buf_name}_buf_filename=$buf_filename"
  eval "${buf_name}_unsaved=$unsaved"
  eval "${buf_name}_mode=(${mode[*]})"
  eval "${buf_name}_modeline_format=$modeline_format"
  eval "${buf_name}_line=$line"
  eval "${buf_name}_col=$col"
  eval "${buf_name}_lines=$lines"
  eval "${buf_name}_buf_size=$buf_size"
  eval "${buf_name}_mark[0]=${mark[0]}"
  eval "${buf_name}_mark[1]=${mark[1]}"
  eval "${buf_name}_buf=(${buf[@]})"
  eval "${buf_name}_bix=(${bix[@]})"
}

load_buf_vars()
{
  buf_name="${1:-$buf_name}"
  local d="\$"
  eval modified=$d${buf_name}_modified
  eval read_only=$d${buf_name}_read_only
  eval buf_name=$d${buf_name}_buf_name
  eval buf_filename=$d${buf_name}_buf_filename
  eval unsaved=$d${buf_name}_unsaved
  eval mode=($d{${buf_name}_mode[*]})
  eval modeline_format=$d${buf_name}_modeline_format
  eval line=$d${buf_name}_line
  eval col=$d${buf_name}_col
  eval lines=$d${buf_name}_lines
  eval buf_size=$d${buf_name}_buf_size
  eval mark[0]=$d${buf_name}_mark[0]
  eval mark[1]=$d${buf_name}_mark[1]
  eval buf=($d{${buf_name}_buf[@]})
  eval bix=($d{${buf_name}_bix[@]})
  typeout doodle_buf
}

# @@@ tmp for debugging
doodle_buf()
{
  local i=0
  for l in ${buf[@]}
  do
    echo "buf[$i] = ($l)"
    i=$[i + 1]
  done
}

buffer_exists()
{
  local buf=$1
  local i=0
  local bufs=${#buffers[*]}
  while [ $i -lt $bufs ]
  do
    if [ "${buffers[$i]}" = "$buf" ]; then
      return 0
    fi
    i=$[i + 1]
  done
  return 1
}

list-buffers()
{
  typeout list_buffers
}

list_buffers()
{
  local i=0
  local bufs=${#buffers[*]}
  local b
  local bl
  local d="\$"
  printf "%-20.20s %8.8s\n" "Name" "Lines"
  while [ $i -lt $bufs ]
  do
    b="${buffers[$i]}"
    if [ "$b" = "$buf_name" ]; then
      bl=$lines
    else
      bl=$(eval echo $d${buffers[$i]}_lines)
    fi
    printf "%-20.20s %8d\n" "$b" "$bl"
    i=$[i + 1]
  done
}

new_buffer()
{
  local n=${#buffers[*]}
  local name="$1"
  buffers[$n]="$name"
  init_buf_vars
  buf_name="$name"
}

switch_to_buffer()
{
  local t_buf="$1"
  save_buf_vars
  if buffer_exists "$t_buf"; then
    load_buf_vars "$t_buf"
  else
    new_buffer "$t_buf"
  fi
}

init_buf_vars()
{
  # buffer vars
  modified=0
  read_only=0
#  buf_name='*scratch*'
  buf_name='scratch'
  buf_filename=
  unsaved=1			# if never saved
  mode[0]='Fundamental'
  modeline_format=		# current modeline format
  line=0			# current line in buffer
  col=0				# current column in buffer
  lines=0			# number of lines in the buffer (index)
  buf_size=1			# size of the buffer text heap
  mark[0]=x			# mark line
  mark[1]=x			# mark col

  # window vars
  win_start=0			# starting buffer line of the window
  win_height=$[screen_rows - 2]
  x=0				# x position on screen
  y=0				# y position on screen
}

init_global_vars()
{
  # System vars
  host=$(uname -n 2> /dev/null)
  host=${host//.*/}		# get rid of anything past first dot
  if [ ! "$host" ] ; then
    host=Bmacs
  fi
  debug_flag=0
  current_buffer=0
  clipboard=''
  need_to_gc_buffer=0
  buffer_gc_threshold=30
  declare -a documentation	# documentation for functions
  declare -a func		# function names
  max_func=0			# index into the above two

  # display vars
  need_to_redraw=0		# true if screen need to be redrawn
  do_update=1			# suppress immediate output of editing commands
  line_to_redraw=x		# screen line number to redraw if not x

  # User preferences
  visible_bell=0
  default_modeline_format='--%+%*-%h: %b  (%m) %p %-'
  update_modeline=0
  saved_modeline=
  next_screen_context_lines=2
  scroll_step=0			# zero for centering
  timeout=60			# second for timeout
  line_numbers=0

  init_term_vars
#  init_code_chars    # way too slow
}

load_init_file()
{
  if [ -f ~/.bmacs ]; then
    # @@@ check that file is writable only by you
    message "Reading ~/.bmacs..."
    source ~/.bmacs		# Security hole @@@
    message "Reading ~/.bmacs...done"
  fi
}

conferr()
{
  echo "Configuration error: "
  echo "$*"
  exit 1
}

required_cmd()
{
  if [ $(type -t $1) != "file" ]; then
    conferr "The required command $1 is missing."
  fi
}

configure()
{
  if [ "$BASH_VERSINFO" -lt 2 ] ; then
    conferr "I'm sorry. You need at least bash version 2.05 for this to work."
  fi
  if [ "$BASH_VERSINFO" -eq 2 -a "${BASH_VERSINFO[1]%[^0-9]*}" -lt 5 ] ; then
    conferr "I'm sorry. You need at least bash version 2.05 for this to work."
  fi

  for cmd in stty tput uname
  do
    required_cmd $cmd
  done

  # use berkeley stty if available
  if [ -x /usr/ucb/stty ]; then
    stty=/usr/ucb/stty
  else
    stty=stty
  fi
}

initialize()
{
  configure
  init_global_vars
#  init_buf_vars
  new_buffer "scratch"
  init_term
  init_keymap
  redraw

  load_init_file
}

parse_args()
{
  if [ $# -eq 1 ]; then
#    debugp "visiting file $1"
    visit-file "$1"
    need_to_redraw=1
  fi
}

###########################################################################
# Editing functions
###########################################################################

doc self-insert "Insert the character that was just typed."
self-insert()
{
  insert "$c"
}

# $1 - string to insert
insert()
{
  debug "insert(\"$1\")"

  if [ $line = $lines ]; then
    lines=$[lines + 1]

    # Take a line from the end of the heap
    bix[$line]=$buf_size
    buf[$buf_size]=''
    buf_size=$[buf_size + 1]
  fi

  local str="$1"
  declare -i len=${#str}
  declare -i bi=${bix[$line]}
  buf[$bi]="${buf[$bi]:0:$col}${str}${buf[$bi]:$col}"
  x=$[x + $len]
  col=$[col + $len]
  echo -n "$1"			# assuming we're in insert mode
  if [ $modified = 0 ]; then
    modified=1
    draw_modeline		# To show modified flag
    moveto $y $x		# goto the cursor location
  fi
}

newline()
{
  debug "$FUNCNAME"
  
  insert_line $[line + 1]
  declare -i bi=${bix[$line]}
  if [ $col != ${#buf[$bi]} ]; then		# not EOL
    # copy tail of old line to new line
    buf[${bix[$line + 1]}]=${buf[$bi]:$col}
    # snip the tail of the old line
    buf[$bi]=${buf[$bi]:0:$col}
  fi
  line=$[line + 1]
  col=0
  y=$[y + 1]
  x=0

  # @@@ what about when we get to the bottom of the window?

  if [ $line -le $[lines - 1] ]; then		# not at the EOB
    bi=${bix[$line]}
    echo "${t_el}"
#    echo -n "${t_il1}${buf[$bi]}"
    echo -n "${t_il1}"
    render_line "${buf[$bi]}"
    moveto $y $x
  else
    echo					# a newline
  fi
}

doc delete-backward-char "Deletes the previous character."
delete-backward-char()
{
  debug "$FUNCNAME"

  if [ $col -eq 0 ]; then
    if [ $line = 0 ] ; then
      message "Beginning of buffer"
      ring_bell
      return
    fi

    # back to the end of the above line
    line=$[line - 1]
    declare -i bi=${bix[$line]}
    x=${#buf[$bi]}
    col=$x
    y=$[y - 1]

    # append the old line to the above line, and delete the old line
    local ol=${buf[${bix[$[line + 1]]}]}
    buf[$bi]="${buf[$bi]}${ol}"
    delete_line $[line + 1]
    echo -n "${t_dl1}"

    if [ $modified = 0 ]; then
      modified=1
      draw_modeline		# To show modified flag
    fi

    # fill in the empty line at the bottom of the window
    moveto $[win_height - 1] 0
    bi=${bix[$win_start + $[win_height - 1]]}
#    echo -n "${buf[$bi]}"
    render_line "${buf[$bi]}"
    moveto $y $x		# goto the cursor location
#    echo -n "$ol"		# write 
    render_line "$ol"		# write 
    moveto $y $x		# go back to the beginning of the line
    return
  fi
  declare -i bi=${bix[$line]}
  buf[$bi]="${buf[$bi]:0:$[col - 1]}${buf[$bi]:$col}"
  x=$[x - 1]
  col=$[col - 1]
  echo -n "$t_cub1$t_dch1"
  if [ $modified = 0 ]; then
    modified=1
    draw_modeline		# To show modified flag
    moveto $y $x		# goto the cursor location
  fi
}

doc delete-char "Deletes the character the cursor is on."
delete-char()
{
  debug "$FUNCNAME"

  declare -i bi=${bix[$line]}
  if [ $col -eq ${#buf[$bi]} ] ; then
    if [ $line -eq $lines ]; then
      message "End of buffer"
      ring_bell
      return
    fi
    # join lines
    local ol=${buf[${bix[$[line + 1]]}]}	# following line
    buf[$bi]="${buf[$bi]}${ol}"			# append to current
    delete_line $[line + 1]

    # update the "view"
#    echo "$ol"			# append the following line and go down
    render_line "$ol"		# append the following line and go down
    echo -n "${t_dl1}"		# delete the following line
    if [ $lines -ge $[win_start + win_height] ]; then 
      # fill in the empty line at the bottom of the window
      moveto $[win_height - 1] 0
      bi=${bix[$win_start + $[win_height - 1]]}
#      echo -n "${buf[$bi]}"
      render_line "${buf[$bi]}"
    fi
    moveto $y $x		# go back to where we were
    return
  fi
  buf[$bi]="${buf[$bi]:0:$col}${buf[$bi]:$[col + 1]}"
  echo -n "$t_dch1"
  if [ $modified = 0 ]; then
    modified=1
    draw_modeline		# To show modified flag
    moveto $y $x		# goto the cursor location
  fi
}

doc kill-word "Kills until the end of the next word."
kill-word()
{
  debug "$FUNCNAME"

  set $(save_excursion forward-word 'command echo "$line $col"')
#  kill_region $1 $2 $line $col
  delete_region $line $col $1 $2 
}

doc kill-line "Kill to the end of the line."
kill-line()
{
  debug "$FUNCNAME"

  declare -i bi=${bix[$line]}
  if [ -z "${buf[$bi]:$col}"  ] ; then
    buf[$bi]="${buf[$bi]}${buf[${bix[$line + 1]}]}"
    delete_line $line
    echo -n "${t_dl1}"

    # fill in the empty line at the bottom of the window
    moveto $[win_height - 1] 0
    bi=${bix[$win_start + $[win_height - 1]]}
#    echo -n "${buf[$bi]}"
    render_line "${buf[$bi]}"
    moveto $y $x		# goto the cursor location
  else
    if [ $line = $lines -a $col = ${#buf[$bi]} ]; then
      ring_bell
      message "End of buffer"
      return
    fi
    clipboard=${buf[$bi]:$col}
    buf[$bi]=${buf[$bi]:0:$col}
    echo -n "$t_el"
    if [ $modified = 0 ]; then
      modified=1
      draw_modeline		# To show modified flag
      moveto $y $x		# goto the cursor location
    fi
  fi
}

doc copy-region "Copy the region to the clipboard."
copy-region()
{
#  clipboard=$(buffer_substring $line $col $mark[0] $mark[1])
  buffer_substring $line $col $mark[0] $mark[1]
  clipboard="$result"
}

yank()
{
  insert "$clipboard"
}

set_mark()
{
  mark[0]=$line
  mark[1]=$col
}

doc set-mark "Set the mark to the current position (the point)."
set-mark()
{
  set_mark
  message "Mark set"
}

# set line and col and update (or set for update) the screen accordingly
set_point()
{
  line=$1
  col=$2

  if [ $line -lt $win_start -o $line -ge $[win_start + win_height] ] ; then
    win_start=$[line - (win_height / 2)]
    if [ $win_start -lt 0 ]; then
      win_start=0
    fi
    need_to_redraw=1
  fi
  y=$[line - win_start]

  line_view_col $line $col
  x=$?

  if [ $need_to_redraw = 0 ]; then
    moveto $y $x
  fi
}

exchange-point-and-mark()
{
  if [ x${mark[0]} = x ]; then
    message "No mark set in this buffer."
    ring_bell
    return 1
  fi

  new_mark_line=$line
  new_mark_col=$col

  set_point ${mark[0]} ${mark[1]}

  mark[0]=$new_mark_line
  mark[1]=$new_mark_col
}

#
# Movement
#

doc beginning-of-line "Move point to the beginning of the current line."
beginning-of-line()
{
  debug "$FUNCNAME"
  x=0
  col=0
  moveto $y 0
}

doc beginning-of-line "Move point to the end of the current line."
end-of-line()
{
  debug "$FUNCNAME"
  declare -i bi=${bix[$line]}
  line_view_len $line
  x=$?
  col=${#buf[$bi]}
  moveto $y $x
}

doc next-line "Move the cursor down one line"
next-line()
{
  debug "$FUNCNAME"

  # End of buffer
  if [ $line -ge $lines ]; then
    ring_bell
    return 1
  fi

  line=$[line + 1]
  declare -i bi=${bix[$line]}
  local old_col=$col
  if [ $col -gt ${#buf[$bi]} ]; then		# col past end of text
    col=${#buf[$bi]}
  fi

  y=$[y + 1]

  # If the cursor is past the bottom of window, adjust the window
  if [ $y -ge $win_height ]; then
    local ss
    if [ $scroll_step = 0 ]; then
      ss=$[win_height / 2]
    else
      ss=$scroll_step
    fi
    win_start=$[win_start + ss];
    y=$[line - win_start]
    x=$col
    need_to_redraw=1
  elif [ $col != $old_col ] ; then	# if we had to adjust the column
    # move the cursor
    line_view_len $line
    x=$?
    moveto $y $x
  else					# we're just going down
# This doesn't work because at least "stty onlcr" is on
#    echo -n "$t_cud1"
#    echo
    tput cud 1
  fi
}

doc previous-line "Move the cursor up one line"
previous-line()
{
  debug "$FUNCNAME"

  if [ $line -eq 0 ]; then
    ring_bell
    return 1
  fi
  line=$[line - 1]
  declare -i bi=${bix[$line]}
  local old_col=$col
  if [ $col -gt ${#buf[$bi]} ]; then
    col=${#buf[$bi]}
  fi

  y=$[y - 1]
  if [ $y -lt 0 ]; then 
    local ss
    if [ $scroll_step = 0 ]; then
      ss=$[win_height / 2]
    else
      ss=$scroll_step
    fi
    win_start=$[win_start - $ss];
    y=$[line - win_start]
    x=$col
    need_to_redraw=1
  elif [ $old_col != $col ] ; then
    line_view_len $line
    x=$?
    moveto $y $x
  else
#    x=$col
    echo -n $t_cuu1
  fi
}

doc forward-char "Move the cursor forward one character."
forward-char()
{
#  debug "$FUNCNAME"

  declare -i bi=${bix[$line]}
  if [ $col -lt ${#buf[$bi]} ]; then
    if [ "${buf[$bi]:$col:1}" = '	' ]; then
      x=$[x + (8 - (x % 8))]
      col=$[col + 1]
      moveto $y $x
    else
      x=$[x + 1]
      col=$[col + 1]
      echo -n $t_cuf1
    fi
  else
    if [ $line -lt $lines ] ; then
      line=$[line + 1]
      y=$[y + 1]
      x=0
      col=0
      moveto $y $x
    else
      message "End of buffer"
      ring_bell
      return
    fi
  fi
}

doc backward-char "Move the cursor backward one character."
backward-char()
{
  debug "$FUNCNAME"

  if [ $col = 0 ]; then
    if [ $line -gt 0 ] ; then
      line=$[line - 1]
      y=$[y - 1]
      declare -i bi=${bix[$line]}
      line_view_len $line
      x=$?
#      message "x=$x"
      col=${#buf[$bi]}
      moveto $y $x
    else
      message "Beginning of buffer"
      ring_bell
      return
    fi
  else
    col=$[col - 1]
    declare -i bi=${bix[$line]}
    if [ "${buf[$bi]:$col:1}" = '	' ]; then
      x=$[x - (8 - (x % 8))]
      moveto $y $x
    else
      x=$[x - 1]
      echo -n $t_cub1
    fi
  fi
}

doc forward-word "Move the cursor forward one word."
forward-word()
{
#  debug "$FUNCNAME"

  # Make sure extended pattern matching is on
  shopt -s extglob

  # if we're at the EOL or the line has no more words
  local ok=0
  declare -i bi
  while [ $ok = 0 ]
  do
    bi=${bix[$line]}
    local l=${buf[$bi]:$col}		   # remaining part of line
    if [ $col -ge ${#buf[$bi]} ] ; then
      if [ $line = $lines ]; then
	message "End of Buffer"
	ring_bell
	return 1
      fi
      line=$[line + 1]
      y=$[y + 1]
      x=0
      col=0
    elif [ "${l##*([^A-Za-z0-9_-])}" = '' ] ; then
      if [ $line = $lines ]; then
	col=0
	x=0
	moveto $y 0
	message "End of buffer"
	ring_bell
	return 1
      fi
      line=$[line + 1]
      y=$[y + 1]
      x=0
      col=0
    else
      ok=1
    fi
  done

  bi=${bix[$line]}
  local l=${buf[$bi]:$col}			   # remaining part of line
  local z=${l##*([^A-Za-z0-9_-])+([A-Za-z0-9_-])}  # end of the next word
  col=$[col + ( ${#l} - ${#z} )]		   # add the difference
  tput cuf $[col - x]				   # forward that many
  x=$col
  moveto $y $x		# @@@ perhaps not totally necessary, but

  # Turn off extended pattern matching so we don't accidentally use it
  shopt -u extglob

  return 0
}

doc backward-word "Move the cursor backward one word."
backward-word()
{
  debug "$FUNCNAME"

  # Make sure extended pattern matching is on
  shopt -s extglob

  # Go backwards to the first line that has a word or return
  local ok=0
  declare -i bi
  while [ $ok = 0 ]
  do
    bi=${bix[$line]}
    local l=${buf[$bi]:0:$col}			# beginning part of line
    if [ $col = 0 ] ; then			# At EOL
      if [ $line = 0 ]; then
	message "Beginning of buffer"
	ring_bell
	return 1
      fi
      line=$[line - 1]
      y=$[y - 1]
      bi=${bix[$line]}
      x=${#buf[$bi]}
      col=$x
    elif [ "${l##*([^A-Za-z0-9_-])}" = '' ] ; then
      if [ $line = 0 ]; then
	col=0
	x=0
	moveto $y 0
	message "Beginning of buffer"
	ring_bell
	return 1
      fi
      line=$[line - 1]
      y=$[y - 1]
      bi=${bix[$line]}
      x=${#buf[$bi]}
      col=$x
    else
      ok=1
    fi
  done

  bi=${bix[$line]}
  local l=${buf[$bi]:0:$col}			   # beginning part of line
  local z=${l%%+([A-Za-z0-9_-])*([^A-Za-z0-9_-])}  # line minus last word
  col=$[col - ( ${#l} - ${#z} )]		   # add the difference
#  tput cub $[x - col]				   # backward that many
  x=$col
  moveto $y $x

  # Turn off extended pattern matching so we don't accidentally use it
  shopt -u extglob
}

doc beginning-of-buffer "Move the cursor to the beginning of the buffer."
beginning-of-buffer()
{
  debug "$FUNCNAME"

  x=0
  y=0
  col=0
  line=0
  if [ $win_start != 0 ]; then
    win_start=0
    need_to_redraw=1
  else
    moveto 0 0
  fi
}

doc end-of-buffer "Move the cursor to the end of the buffer."
end-of-buffer()
{
  debug "$FUNCNAME"

  line=$lines
  declare -i bi=${bix[$line]}
  x=${#buf[$bi]}
  col=$x
  if [ $[line - win_start] -gt $win_height ]; then
    win_start=$[line - (win_height / 2)]
    y=$[line - win_start]
    need_to_redraw=1
  else
    y=$[line - win_start]
    moveto $y $x
  fi
}

doc scroll-up "Scroll the window almost a screenful up."
scroll-up()
{
  debug "$FUNCNAME"

  local new_top=$[win_start + (win_height - next_screen_context_lines)]
  if [ $new_top -gt $lines ]; then
    ring_bell
    return
  fi
  if [ $new_top -gt $[lines - next_screen_context_lines] ] ; then
    new_top=$[lines - next_screen_context_lines]
    if [ $new_top -lt 0 ]; then	# is this possible?
      new_top=0
    fi
  fi
  win_start=$new_top
  line=$win_start
  y=0
  x=0
  col=0
  need_to_redraw=1
}

doc scroll-down "Scroll the window almost a screenful down."
scroll-down()
{
  debug "$FUNCNAME"

  if [ $win_start = 0 ]; then
    ring_bell
    return
  fi

  local new_top=$[win_start - (win_height - next_screen_context_lines)]
  if [ $new_top -lt 0 ]; then
    new_top=0
  fi
  win_start=$new_top
  line=$[win_start + (win_height - 1)]
  y=$[win_height - 1]
  x=0
  col=0
  need_to_redraw=1
}

up-a-line()
{
  if [ $[win_start + 1] -ge $lines ]; then
    ring_bell
    return
  fi
  win_start=$[win_start + 1]
  y=$[y - 1]
  moveto 0 0
  echo -n "${t_dl1}"
  redraw_line $[win_height - 1]
  if [ $win_start -gt $line ]; then
    line=$win_start
    y=0
    x=0
    col=0
  fi
  moveto $y $x
}

down-a-line()
{
  if [ $[win_start - 1] -lt 0 ]; then
    ring_bell
    return
  fi
  win_start=$[win_start - 1]
  y=$[y + 1]
  moveto 0 0
  echo -n "${t_il1}"
  redraw_line 0
  if [ $line -ge $[win_start + win_height] ]; then
    line=$[win_start + (win_height - 1)]
    y=$[win_height - 1]
    x=0
    col=0
  fi
  moveto $y $x
}

last_search=""

doc search-forward "Search for the next occurance of a string." 
search-forward()
{
  if new_prompt "Search [$last_search]: " ; then : ;
  else
    return 1
  fi
  local str="$response"
  local l
  local first_time=1
  local i=$line

  if [ -z "$str" ]; then
    str="$last_search"
  else
    last_search="$str"
  fi

  while [ $i -lt $lines ]
  do
    bi=${bix[$i]}
    if [ $first_time = 1 ]; then
      l="${buf[$bi]:$col}"
      first_time=0
    else
      l="${buf[$bi]}"
    fi
    if [ ${#l} != 0 -a -z "${l##*${str}*}" ]; then
      line=$i
      l=${l%${str}*}
      col=$[${#l} + ${#str}]
      x=$col
      if [ $line -lt $win_start -o \
  	   $line -ge $[win_start + win_height] ]; then
  	need_to_redraw=1
      else
        y=$[line - win_start]
	moveto $y $x
      fi
      set_point $line $col
      return
    fi
    i=$[i + 1]
  done
  message "Not found."
}

###########################################################################
# Buffer functions
###########################################################################

kill-buffer()
{
  debug "$funcname"

  # @@@ this is so fake

  local bufname
  prompt "Kill buffer: (default ${buf_name}) "
  bufname="$response"

  init_buf_vars
  unset buf
  unset bix
  need_to_redraw=1
}

switch-to-buffer()
{
  debug "$funcname"

  local bufname
  prompt "Switch to buffer: (default ${buf_name}) "
  if [ "x$response" = "x" ]; then
    bufname="$buf_name"
  else
    bufname="$response"
  fi

  switch_to_buffer "$bufname"
  need_to_redraw=1
}

gc_buffer()
{
  if [ $need_to_gc_buffer -lt $buffer_gc_threshold ]; then
    return
  fi

  message "Garbage collecting..."

  # This is stupid
  local i
#  for (( i=0 ; i < lines; i=$[i + 1] ))
#  do
#    new_buf[$[i + 1]]=${buf[${bix[$i]}]}
#  done
  i=0
  while [ $i -lt $lines ]
  do
    new_buf[$[i + 1]]=${buf[${bix[$i]}]}
    i=$[i + 1]
  done
  new_buf[0]=''

  buf=("${new_buf[@]}")

#  for (( i=0 ; i < lines; i=$[i + 1] ))
#  do
#    bix[$i]=$[i + 1]
#  done
  i=0
  while [ $i -lt $lines ]
  do
    bix[$i]=$[i + 1]
    i=$[i + 1]
  done

  need_to_gc_buffer=0

  message "Garbage collecting...done"
}

# before  after
#   1       1     
#   2       2
# > 3   4   4
#   4   5   5
#   5       5   0

delete_line()
{
  declare -i at="$1"
  declare -i i

#   for (( i=$at; i < $[lines - 1]; i=$[i + 1] ))
#   do
#     bix[$i]=${bix[i + 1]}
#   done
  i=$at
  while [ $i -lt $[lines - 1] ]
  do
    bix[$i]=${bix[i + 1]}
    i=$[i + 1]
  done
  bix[$i]=0			# clear magic last last

  lines=$[lines - 1]

  need_to_gc_buffer=$[need_to_gc_buffer + 1]
}

insert_line()
{
  declare -i at="$1"
  declare -i i

  if [ $at != $lines ]; then
#     for (( i=$lines; i > $at; i=$[i - 1] ))
#     do
#       bix[$i]=${bix[$i - 1]}
#     done
    i=$lines
    while [ $i -gt $at ]
    do
      bix[$i]=${bix[$i - 1]}
      i=$[i - 1]
    done
  fi
  lines=$[lines + 1]
  bix[$lines]=0			# magic last line

  # Take a line from the end of the heap
  bix[$at]=$buf_size
  buf[$buf_size]=''
  buf_size=$[buf_size + 1]

  need_to_gc_buffer=$[need_to_gc_buffer + 1]
}

delete_region()
{
  beg_line=$1
  beg_col=$2
  end_line=$3
  end_col=$4

  declare -i bi
  if [ $beg_line = $end_line ]; then		# easy case: on one line
    bi=${bix[$beg_line]}
    buf[$bi]="${buf[$bi]:0:$beg_col}${buf[$bi]:$[end_col + 1]}"

    if [ $beg_line -ge $win_start -a \
         $beg_line -lt $[win_start + win_height] ]; then
      moveto $[beg_line - win_start] $beg_col
#      echo -n "${t_el}${buf[$bi]:$beg_col}"
      echo -n "${t_el}"
      render_line "${buf[$bi]:$beg_col}"
      moveto $y $x
    fi
  elif [ $beg_line -lt $end_line ]; then
    need_to_redraw=1
  else
    need_to_redraw=1
  fi

  if [ $modified = 0 ]; then
    modified=1
  fi
}

buffer_substring()
{
  beg_line=$1
  beg_col=$2
  end_line=$3
  end_col=$4
  debugp "buffer_substring $1 $2 $3 $4"

#    local str			# the substring
#    declare -i bi			# buffer index
#    if [ $beg_line = $end_line ]; then		# easy case: on one line
#      bi=${bix[$beg_line]}
#      str=${buf[$bi]:$beg_col:$[end_col + 1]}
#    else				# multiple lines
#      # the first line
#      bi=${bix[$beg_line]}
#      str=${buf[$bi]:$beg_col}

#      # the middle lines
#      local i=$beg_line
#      while [ $i -lt $end_line ]
#      do
#        bi=${bix[$i]}
#        str=${str}${buf[$bi]}
#        i=$[i + 1]
#      done

#      # the last line
#      bi=${bix[$end_line]}
#      str=${str}${buf[$bi]:0:$end_col}
#    fi
#  echo "$str"
  result="$str"
  return 0
}

###########################################################################
# File IO
###########################################################################

# Read a file into the buffer
read-file()
{
  if [ $# != 1 ]; then
    return 1
  fi
  local filename="$1"
  local ln
  declare -i i=0
  unset buf
  unset bix
  {
    while IFS= read ln
    do
      bix[$i]=$[i + 1]
      buf[$i + 1]="$ln"
      i=$[i + 1]
    done
  } < $filename
  lines=$i
  buf_size=$[lines + 2]
  buf[0]=''
  bix[$lines]=0
  return 0
}

write-buffer()
{
  if [ $# != 1 ]; then
    return 1
  fi

  local filename="$1"
  local ln
  declare -i i=0
  declare -i bi=0

  {
#     for (( i=0; i < lines; i++ ))
#     do
#       bi=${bix[$i]}
#       echo "${buf[$bi]}"
#     done
    i=0
    while [ $i -lt $lines ]
    do
      bi=${bix[$i]}
      echo "${buf[$bi]}"
      i=$[i + 1]
    done
  } > $filename

  return 0
}

# Foreshortened substition doc:
#
# P:-W    If P is null, use W is else P.
# P:=W    If P is null, assign P=W. (can't do special params)
# P:?W    If P is null, write W to stderr and exit
# P:+W    If P is null, use NOTHING else W
# P:O     P starting at offset O. Negative offset must be: ${P: -O}
# P:O:L   P starting at offset O for length L. Negative L is from end.
# !P*     Variables beginning with P
# !N[*]   Indexes in array N. Use @ instead of * for doublequoted words.
# #P      Length of P. If P[*] then array element count.
# P#W     Clip shortest head of P matching W. ## is longest head of P.
# P%W     Clip shortest tail of P matching W. %% is longest tail of P.
# P/E/S   Replace first E in P with S. S can be omitted to delete.
# P//E/S  Replace all E in P with S.
# P/#E/S  Replace E beginning P with S.
# P/%E/S  Replace E ending P with S.
#
# "[:" class ":]" 
# where class is one of:
#  alnum   alpha   ascii   blank   cntrl   digit   graph   lower
#  print   punct   space   upper   word    xdigit
#
# extglob:
# PATTERN-LIST          [pattern [| pattern]]
# `?(PATTERN-LIST)'     zero or one
# `*(PATTERN-LIST)'     zero or more
# `+(PATTERN-LIST)'     one or more
# `@(PATTERN-LIST)'     one
# `!(PATTERN-LIST)'     anything except one

colorize_keyword()
{
  # magenta back to green
  syntax_line=${syntax_line// "$1" /'[35m' ${1} '[32m'}
  syntax_line=${syntax_line/#"$1" /'[35m'${1} '[32m'}
  syntax_line=${syntax_line/%"$1"/'[35m'${1}'[32m'}
}

colorize_builtin()
{
  # blue back to green
  syntax_line=${syntax_line// "$1" /'[34m' ${1} '[32m'}
  syntax_line=${syntax_line/#"$1" /'[34m'${1} '[32m'}
  syntax_line=${syntax_line/%"$1"/'[34m'${1}'[32m'}
}

colorize_var()
{
  : # syntax_line=$
}

colorize_comment()
{
  local s="$syntax_line"
  # cyan back to green
  syntax_line=${s/%"$1"*/'[36m'#${s#*#}'[32m'}
  if [ ${#s} != ${#syntax_line} ]; then
    return 0
  else
    return 1
  fi
}

colorize_string()
{
  local s="$syntax_line"
  # cyan back to green
  local inside="${s#*[^$1]$1}"
  inside="${inside%\"*([^$1])}"
  syntax_line=${s//$1*[^$1]\"/'[37m'$1$inside$1'[32m'}
}

bash_keywords="if fi then else elif while do done for case esac return echo read true exit break"

bash_builtins="alias bg cd declare dirs echo eval export jobs kill let local nohup printf pushd pwd read set shift shopt source suspend time typeset ulimit unalias unset wait"

# Colorizer for bash-mode
bash-mode-colorize()
{
  syntax_line="$1"
  if [ "$syntax_line" ]; then
    if colorize_comment "#" ; then
      :
    else
      for k in $bash_keywords
      do
	colorize_keyword "$k"
      done
      for k in $bash_builtins
      do
	colorize_builtin "$k"
      done
      colorize_string '"'
      colorize_string "'"
    fi
  fi
}

# Mode for editing bash code
bash-mode()
{
  colorizer=bash-mode-colorize
  mode[0]='Bash'
}

# set a file's mode based on file name or shebang
set-file-mode()
{
  # shebang
  if [ "${buf[1]:0:3}" = '#!/' -a "${buf[1]: -4}" = 'bash' ] ; then
    bash-mode
  elif [ -z "${buf[1]##*-\*- * -\*-*}" ]; then
    # mode string
    local mode=${buf[1]#*-\*- }
    mode=${mode% -\*-*}
    case "$mode" in
      ksh|sh-mode|sh-script|bash) bash-mode ;;
    esac
  fi
}

visit-file()
{
  local filename="$1"
  local b_name="${filename##*/}"

  switch_to_buffer "$b_name"
  read-file "$filename"
  set-file-mode
  modified=0
  buf_filename="$filename"
  buf_name="$b_name"
  line=0
  col=0
  x=0
  y=0
  win_start=0
}

find-file()
{
  local filename
  prompt "Find file: "
  filename=$(eval "echo $response") # eval so we can expand ~ $var etc..
  if [ -f "$filename" ]; then
    visit-file "$filename"
    need_to_redraw=1
  else
    local b_name="${filename##*/}"
    new_buffer "$b_name"
    buf_filename="$filename"
    buf_name="$b_name"
    redraw
    message '(New file)'
  fi
}

save-buffer()
{
  if [ $modified = 0 ]; then
    message "(No changes need be saved)"
    return
  fi
  if [ -z "$buf_filename" ] ; then
    if prompt "Write file: " ; then
      if [ ! "$response" ]; then
	message "Not saving"
	return
      else
	buf_filename="$response"
      fi
    else
      return			# eof or error
    fi
  fi

  # make a backup the first time saving
  if [ -f "$buf_filename" -a $unsaved = 1 ]; then
    mv "$buf_filename" "$buf_filename"~
  fi

  write-buffer "$buf_filename"
  message "Wrote $buf_filename"
  modified=0
  unsaved=0
}

###########################################################################
# Interrupts, cleanup and exiting
###########################################################################

keyboard-quit()
{
  debug "$FUNCNAME"
  ring_bell
}

suspend-bmacs()
{
  echo -n "$t_clear"
  moveto $screen_rows 0	# goto to bottom of the screen
  reset_term

  # why doesn't "suspend" work
  kill -TSTP $$

  init_term
  need_to_redraw=1
}

fatal()
{
  reset_term
  echo -e "$*\n"
  exit 1
}

kill-bmacs()
{
  quit
}

quit()
{
  echo -n "$t_clear"
  moveto $screen_rows 0	# goto to bottom of the screen
  reset_term
  exit 0
}

interrupt()
{
  trap INT			# remove interrupt signal handler
  echo 'Interrupt!'
  quit
}

winch()
{
  #trap WINCH			# remove interrupt signal handler
  get_screen_size
  need_to_redraw=1
#  echo 'Winch!'
}

garbage_collect()
{
  gc_buffer
}

###########################################################################
# Debugging
###########################################################################

debug()
{
  if [ x$debug_flag = x1 ] ; then
    message "$*"
  fi
}

debugp()			# with pause
{
  if [ x$debug_flag = x1 ] ; then
    message "$*"
    read -sr -d '' -n 1
  fi
}

###########################################################################
# Keymaps
###########################################################################

# This is so meta characters below won't get interpreted as multi-byte
if [ x$LANG != x ]; then
  saved_LANG=$LANG
  LANG=C
fi
if [ x$LC_CTYPE != x ]; then
  saved_LC_CTYPE=$LC_CTYPE
  LC_CTYPE=C
fi

# This is way too slow, but how else can we do it?
init_code_chars()
{
  local i=0
  while [ $i -lt 256 ]
  do
    v_code_char[$i]=$(echo -e "\\"$(printf "%03o" $i))
    let "i++"
  done
}

# Outputs the character for the given integer code
code_char()
{
  echo ${v_code_char[$1]}
}

# @@@ Is there a better way to do this without using an external program?
char_to_int()
{
  case "$1" in
    # Control chars
    ^@) return 0 ;;		# special case
    ) return 1 ;; ) return 2 ;; ) return 3 ;;
    ) return 4 ;; ) return 5 ;; ) return 6 ;; ) return 7 ;;
    ) return 8 ;;

    # Ye olde whitespace
    "	") return 9 ;;
    "
") return 10 ;;

    # more controls
    ) return 11 ;; ) return 12 ;; ) return 13 ;; ) return 14 ;;
    ) return 15 ;; ) return 16 ;; ) return 17 ;; ) return 18 ;;
    ) return 19 ;; ) return 20 ;; ) return 21 ;; ) return 22 ;;
    ) return 23 ;; ) return 24 ;; ) return 25 ;; ) return 26 ;;
    ) return 27 ;; ) return 28 ;; ) return 29 ;; ) return 30 ;;
    ) return 31 ;;

    # Space
    " ") return 32 ;;

    # Pucntuation
    \!) return 33 ;; \") return 34 ;; \#) return 35 ;; \$) return 36 ;;
    \%) return 37 ;; \&) return 38 ;; \') return 39 ;; \() return 40 ;;
    \)) return 41 ;; \*) return 42 ;; \+) return 43 ;; \,) return 44 ;;
    -) return 45 ;; .) return 46 ;; /) return 47 ;;

    # Numbers
    0) return 48 ;; 1) return 49 ;; 2) return 50 ;; 3) return 51 ;;
    4) return 52 ;; 5) return 53 ;; 6) return 54 ;; 7) return 55 ;;
    8) return 56 ;; 9) return 57 ;;

    # More pucntuation
    :) return 58 ;; \;) return 59 ;; \<) return 60 ;; =) return 61 ;;
    \>) return 62 ;; \?) return 63 ;; @) return 64 ;;

    # Capitol letters
    A) return 65 ;; B) return 66 ;; C) return 67 ;; D) return 68 ;;
    E) return 69 ;; F) return 70 ;; G) return 71 ;; H) return 72 ;;
    I) return 73 ;; J) return 74 ;; K) return 75 ;; L) return 76 ;;
    M) return 77 ;; N) return 78 ;; O) return 79 ;; P) return 80 ;;
    Q) return 81 ;; R) return 82 ;; S) return 83 ;; T) return 84 ;;
    U) return 85 ;; V) return 86 ;; W) return 87 ;; X) return 88 ;;
    Y) return 89 ;; Z) return 90 ;;

    # Even more pucntuation
    \[) return 91 ;; \\) return 92 ;; \]) return 93 ;; \^) return 94 ;;
    _) return 95 ;; \`) return 96 ;;

    # Lowercase letters
    a) return 97 ;;  b) return 98 ;;  c) return 99  ;; d) return 100 ;;
    e) return 101 ;; f) return 102 ;; g) return 103 ;; h) return 104 ;;
    i) return 105 ;; j) return 106 ;; k) return 107 ;; l) return 108 ;;
    m) return 109 ;; n) return 110 ;; o) return 111 ;; p) return 112 ;;
    q) return 113 ;; r) return 114 ;; s) return 115 ;; t) return 116 ;;
    u) return 117 ;; v) return 118 ;; w) return 119 ;; x) return 120 ;;
    y) return 121 ;; z) return 122 ;;

    # Yet more pucntuation
    \{) return 123 ;; \|) return 124 ;; \}) return 125 ;; \~) return 126 ;;

    # Delete
    ) return 127 ;;

    # Hibittypiddles
    # Problem: If LC_CTYPE is not C (or equivalent) these can have
    # multibyte interpretations, which we don't want.
    Ä) return 128 ;; Å) return 129 ;; Ç) return 130 ;;
    É) return 131 ;; Ñ) return 132 ;; Ö) return 133 ;;
    Ü) return 134 ;; á) return 135 ;; à) return 136 ;;
    â) return 137 ;; ä) return 138 ;; ã) return 139 ;;
    å) return 140 ;; ç) return 141 ;; é) return 142 ;;
    è) return 143 ;; ê) return 144 ;; ë) return 145 ;;
    í) return 146 ;; ì) return 147 ;; î) return 148 ;;
    ï) return 149 ;; ñ) return 150 ;; ó) return 151 ;;
    ò) return 152 ;; ô) return 153 ;; ö) return 154 ;;
    õ) return 155 ;; ú) return 156 ;; ù) return 157 ;;
    û) return 158 ;; ü) return 159 ;;

    # latin1 foozers
    †) return 160 ;; °) return 161 ;; ¢) return 162 ;; £) return 163 ;;
    §) return 164 ;; •) return 165 ;; ¶) return 166 ;; ß) return 167 ;;
    ®) return 168 ;; ©) return 169 ;; ™) return 170 ;; ´) return 171 ;;
    ¨) return 172 ;; ≠) return 173 ;; Æ) return 174 ;; Ø) return 175 ;;
    ∞) return 176 ;; ±) return 177 ;; ≤) return 178 ;; ≥) return 179 ;;
    ¥) return 180 ;; µ) return 181 ;; ∂) return 182 ;; ∑) return 183 ;;
    ∏) return 184 ;; π) return 185 ;; ∫) return 186 ;; ª) return 187 ;;
    º) return 188 ;; Ω) return 189 ;; æ) return 190 ;; ø) return 191 ;;
    ¿) return 192 ;; ¡) return 193 ;; ¬) return 194 ;; √) return 195 ;;
    ƒ) return 196 ;; ≈) return 197 ;; ∆) return 198 ;; «) return 199 ;;
    ») return 200 ;; …) return 201 ;;  ) return 202 ;; À) return 203 ;;
    Ã) return 204 ;; Õ) return 205 ;; Œ) return 206 ;; œ) return 207 ;;
    –) return 208 ;; —) return 209 ;; “) return 210 ;; ”) return 211 ;;
    ‘) return 212 ;; ’) return 213 ;; ÷) return 214 ;; ◊) return 215 ;;
    ÿ) return 216 ;; Ÿ) return 217 ;; ⁄) return 218 ;; €) return 219 ;;
    ‹) return 220 ;; ›) return 221 ;; ﬁ) return 222 ;; ﬂ) return 223 ;;
    ‡) return 224 ;; ·) return 225 ;; ‚) return 226 ;; „) return 227 ;;
    ‰) return 228 ;; Â) return 229 ;; Ê) return 230 ;; Á) return 231 ;;
    Ë) return 232 ;; È) return 233 ;; Í) return 234 ;; Î) return 235 ;;
    Ï) return 236 ;; Ì) return 237 ;; Ó) return 238 ;; Ô) return 239 ;;
    ) return 240 ;; Ò) return 241 ;; Ú) return 242 ;; Û) return 243 ;;
    Ù) return 244 ;; ı) return 245 ;; ˆ) return 246 ;; ˜) return 247 ;;
    ¯) return 248 ;; ˘) return 249 ;; ˙) return 250 ;; ˚) return 251 ;;
    ¸) return 252 ;; ˝) return 253 ;; ˛) return 254 ;; ˇ) return 255 ;;
  esac
  return -1;			# @@@ Bad! XXX
}
if [ x$saved_LANG != x ]; then
  LANG=$saved_LANG
fi
if [ x$saved_LC_CTYPE != x ]; then
  LC_CTYPE=$saved_LC_CTYPE
fi

#  test_char_to_int()
#  {
#    until false
#    do
#      IFS=: read -sr -d '' -n 1 c
#      char_to_int "$c"
#      echo $?
#    done
#  }

# int to character description
# this really stupid
char_desc()
{
  local ce="command echo"
  case "$1" in
    # Control chars
    0) $ce '^@' ;; 1) $ce '^A' ;; 2) $ce '^B' ;; 3) $ce '^C' ;;
    4) $ce '^D' ;; 5) $ce '^E' ;; 6) $ce '^F' ;; 7) $ce '^G' ;;
    8) $ce '^H' ;;

    # Ye olde whitespace
    9) $ce '^I' ;;
    10) $ce '^J' ;;

    # more controls
    11) $ce '^K' ;; 12) $ce '^L' ;; 13) $ce '^M' ;; 14) $ce '^N' ;;
    15) $ce '^O' ;; 16) $ce '^P' ;; 17) $ce '^Q' ;; 18) $ce '^R' ;;
    19) $ce '^S' ;; 20) $ce '^T' ;; 21) $ce '^U' ;; 22) $ce '^V' ;;
    23) $ce '^W' ;; 24) $ce '^X' ;; 25) $ce '^Y' ;; 26) $ce '^Z' ;;
    27) $ce '^[' ;; 28) $ce '^\\' ;; 29) $ce '^]' ;; 30) $ce '^^';;
    31) $ce '^_' ;;

    # Space
    32) $ce 'Space' ;;

    # Pucntuation
    33) $ce '!';; 34) $ce '"';; 35) $ce '#';; 36) $ce "\$";;
    37) $ce '%';; 38) $ce '&';; 39) $ce "\'";; 40) $ce '(';;
    41) $ce ')';; 42) $ce '*';; 43) $ce '+';; 44) $ce ',';;
    45) $ce '-';; 46) $ce '.';; 47) $ce '/';;

    # Numbers
    48) $ce '0';; 49) $ce '1';; 50) $ce '2';; 51) $ce '3';;
    52) $ce '4';; 53) $ce '5';; 54) $ce '6';; 55) $ce '7';;
    56) $ce '8';; 57) $ce '9';;

    # More pucntuation
    58) $ce ':';; 59) $ce ';' ;; 60) $ce '<' ;; 61) $ce '=' ;;
    62) $ce '>' ;; 63) $ce '?' ;; 64) $ce '@' ;;

    # Capitol letters
    65) $ce 'A';; 66) $ce 'B';; 67) $ce 'C';; 68) $ce 'D';;
    69) $ce 'E';; 70) $ce 'F';; 71) $ce 'G';; 72) $ce 'H';;
    73) $ce 'I';; 74) $ce 'J';; 75) $ce 'K';; 76) $ce 'L';;
    77) $ce 'M';; 78) $ce 'N';; 79) $ce 'O';; 80) $ce 'P';;
    81) $ce 'Q';; 82) $ce 'R';; 83) $ce 'S';; 84) $ce 'T';;
    85) $ce 'U';; 86) $ce 'V';; 87) $ce 'W';; 88) $ce 'X';;
    89) $ce 'Y';; 90) $ce 'Z';;

    # Even more pucntuation
    91) $ce '[' ;; 92) $ce '\\';; 93) $ce ']';; 94) $ce '^';;
    95) $ce '_' ;; 96) $ce '`' ;;

    # Lowercase letters
    97)  $ce 'a';;  98) $ce 'b';;  99) $ce 'c';; 100) $ce 'd';;
    101) $ce 'e';; 102) $ce 'f';; 103) $ce 'g';; 104) $ce 'h';;
    105) $ce 'i';; 106) $ce 'j';; 107) $ce 'k';; 108) $ce 'l';;
    109) $ce 'm';; 110) $ce 'n';; 111) $ce 'o';; 112) $ce 'p';;
    113) $ce 'q';; 114) $ce 'r';; 115) $ce 's';; 116) $ce 't';;
    117) $ce 'u';; 118) $ce 'v';; 119) $ce 'w';; 120) $ce 'x';;
    121) $ce 'y';; 122) $ce 'z';;

    # Yet more pucntuation
    123) $ce '{';; 124) $ce '|';; 125) $ce '}' ;; 126) $ce '~';;

    # Delete
    127) $ce 'Delete' ;;

    # Hibittypiddles
    128) $ce 'C-M-@' ;; 129) $ce 'C-M-a' ;; 130) $ce 'C-M-b' ;;
    131) $ce 'C-M-c' ;; 132) $ce 'C-M-d' ;; 133) $ce 'C-M-e' ;;
    134) $ce 'C-M-f' ;; 135) $ce 'C-M-g' ;; 136) $ce 'C-M-h' ;;
    137) $ce 'M-TAB' ;; 138) $ce 'M-LFD' ;; 139) $ce 'C-M-k' ;;
    140) $ce 'C-M-l' ;; 141) $ce 'M-RET' ;; 142) $ce 'C-M-n' ;;
    143) $ce 'C-M-o' ;; 144) $ce 'C-M-p' ;; 145) $ce 'C-M-q' ;;
    146) $ce 'C-M-r' ;; 147) $ce 'C-M-s' ;; 148) $ce 'C-M-t' ;;
    149) $ce 'C-M-u' ;; 150) $ce 'C-M-v' ;; 151) $ce 'C-M-w' ;;
    152) $ce 'C-M-x' ;; 153) $ce 'C-M-y' ;; 154) $ce 'C-M-z' ;;
    155) $ce 'M-ESC' ;; 156) $ce 'C-M-\\' ;; 157) $ce 'C-M-]' ;;
    158) $ce 'C-M-^' ;; 159) $ce 'C-M-_' ;;

    # latin1 foozers
    160) $ce 'M-SPC';; 161) $ce 'M-!';; 162) $ce 'M-"';;
    163) $ce 'M-#';; 164) $ce "M-\$";; 165) $ce 'M-%';;
    166) $ce 'M-&';; 167) $ce "M-'";; 168) $ce 'M-(';;
    169) $ce 'M-)';; 170) $ce 'M-*';; 171) $ce 'M-+';;
    172) $ce 'M-,';; 173) $ce 'M--';; 174) $ce 'M-.';;
    175) $ce 'M-/';; 176) $ce 'M-0';; 177) $ce 'M-1';;
    178) $ce 'M-2';; 179) $ce 'M-3';; 180) $ce 'M-4';;
    181) $ce 'M-5';; 182) $ce 'M-6';; 183) $ce 'M-7';;
    184) $ce 'M-8';; 185) $ce 'M-9';; 186) $ce 'M-:';;
    187) $ce 'M-;';; 188) $ce 'M-<';; 189) $ce 'M-=';;
    190) $ce 'M->';; 191) $ce 'M-?';; 192) $ce 'M-@';;
    193) $ce 'M-A';; 194) $ce 'M-B';; 195) $ce 'M-C';;
    196) $ce 'M-D';; 197) $ce 'M-E';; 198) $ce 'M-F';;
    199) $ce 'M-G';; 200) $ce 'M-H';; 201) $ce 'M-I';;
    202) $ce 'M-J';; 203) $ce 'M-K';; 204) $ce 'M-L';;
    205) $ce 'M-M';; 206) $ce 'M-N';; 207) $ce 'M-O';;
    208) $ce 'M-P';; 209) $ce 'M-Q';; 210) $ce 'M-R';;
    211) $ce 'M-S';; 212) $ce 'M-T';; 213) $ce 'M-U';;
    214) $ce 'M-V';; 215) $ce 'M-W';; 216) $ce 'M-X';;
    217) $ce 'M-Y';; 218) $ce 'M-Z';; 219) $ce 'M-[';;
    220) $ce 'M-\\';; 221) $ce 'M-]';; 222) $ce 'M-^';;
    223) $ce 'M-_';; 224) $ce 'M-`';; 225) $ce 'M-a';;
    226) $ce 'M-b';; 227) $ce 'M-c';; 228) $ce 'M-d';;
    229) $ce 'M-e';; 230) $ce 'M-f';; 231) $ce 'M-g';;
    232) $ce 'M-h';; 233) $ce 'M-i';; 234) $ce 'M-j';;
    235) $ce 'M-k';; 236) $ce 'M-l';; 237) $ce 'M-m';;
    238) $ce 'M-n';; 239) $ce 'M-o';; 240) $ce 'M-p';;
    241) $ce 'M-q';; 242) $ce 'M-r';; 243) $ce 'M-s';;
    244) $ce 'M-t';; 245) $ce 'M-u';; 246) $ce 'M-v';;
    247) $ce 'M-w';; 248) $ce 'M-x';; 249) $ce 'M-y';;
    250) $ce 'M-z';; 251) $ce 'M-{';; 252) $ce 'M-|';;
    253) $ce 'M-}';; 254) $ce 'M-~';; 255) $ce 'M-DEL';;

    # whatever?
    *) $ce "Unknown";;
  esac
}

init_keymap()
{
  global_map[0]='set-mark'
  global_map[1]='beginning-of-line'
  global_map[2]='backward-char'
  global_map[3]='control-fucking-c-dude'	# @@@
  global_map[4]='delete-char'
  global_map[5]='end-of-line'
  global_map[6]='forward-char'
  global_map[7]='keyboard-quit'			# @@@ what should this do?
#  global_map[8]='delete-backward-char'		# not help!
  global_map[8]='help-command'		# @@@ should be based on stty erase
  global_map[9]='self-insert'			# not indent!
  global_map[10]='newline'
  global_map[11]='kill-line'
  global_map[12]='redraw'
  global_map[13]='newline'
  global_map[14]='next-line'
  # i never use this, so i've allways wanted to change it into (^O)ops! (undo)?
  global_map[15]='open-line'
  global_map[16]='previous-line'
  global_map[17]='quote-char'
  global_map[18]='search-backward'
  global_map[19]='search-forward'
  global_map[20]='transpose-chars'		# i don't use this
  global_map[21]='universal-oneness'
  global_map[22]='scroll-up'
  global_map[23]='kill-region'			# wipe my ass
  global_map[24]='ctrl-x-map'
  global_map[25]='yank'
  global_map[26]='up-a-line'			# i am rocksor

  global_map[27]='esc-map'
  global_map[28]=''				# C-\ what a waste!
  global_map[29]=''				# @@ no recursive edit y0!
  global_map[30]=''				# wastage!
  global_map[31]='undo'

  local i
#   for (( i=32 ; i < 126 ; i++ ))
#   do
#     global_map[$i]='self-insert'
#   done
  i=32
  while [ $i -lt 126 ]
  do
    global_map[$i]='self-insert'
    i=$[i + 1]
  done

  global_map[127]='delete-backward-char'

  # Meta chars
  global_map[160]='set-mark'			# meta-space (non-standard)
  global_map[188]='beginning-of-buffer'		# meta-<
  global_map[189]='describe-key-briefly'	# meta-=
  global_map[190]='end-of-buffer'		# meta->
  global_map[196]='toggle-debug'		# meta-D
  global_map[226]='backward-word'		# meta-b
  global_map[228]='kill-word'			# meta-d
  global_map[230]='forward-word'		# meta-f
  global_map[246]='scroll-down'			# meta-v
  global_map[236]='toggle-line-numbers'		# meta-l
  global_map[237]='toggle-update-modeline'	# meta-m
  global_map[247]='copy-region'			# meta-w
  global_map[248]='execute-extended-command'	# meta-x
  global_map[250]='down-a-line'			# meta-z
  global_map[255]='set-mark'			# meta-?

  # Control-X map
  ctrl_x_map[2]='list-buffers'			# C-x C-b
  ctrl_x_map[3]='kill-bmacs'			# C-x C-c
  ctrl_x_map[6]='find-file'			# C-x C-f
  ctrl_x_map[19]='save-buffer'			# C-x C-s
  ctrl_x_map[24]='exchange-point-and-mark'	# C-x C-x
  ctrl_x_map[26]='suspend-bmacs'		# C-x C-z
  ctrl_x_map[98]='switch-to-buffer'		# C-x b
  ctrl_x_map[107]='kill-buffer'			# C-x k

  # ESC map
  esc_map[32]='set-mark'			# ESC space (non-standard)
  esc_map[60]='beginning-of-buffer'		# ESC <
  esc_map[61]='describe-key-briefly'		# ESC =
  esc_map[62]='end-of-buffer'			# ESC >
  esc_map[68]='toggle-debug'			# ESC D
  esc_map[91]='funkey'				# ESC [
  esc_map[98]='backward-word'			# ESC b
  esc_map[100]='kill-word'			# ESC d
  esc_map[102]='forward-word'			# ESC f
  esc_map[108]='toggle-line-numbers'		# ESC l
  esc_map[109]='toggle-update-modeline'		# ESC m
  esc_map[119]='copy-region'			# ESC w
  esc_map[120]='execute-extended-command'	# ESC x
  esc_map[118]='scroll-down'			# ESC v
  esc_map[122]='down-a-line'			# ESC z

  # minibuf map
  mini_map=(${global_map[*]})
  mini_map[7]='minibuf-abort'			# C-g
  mini_map[9]='minibuf-complete'		# C-i (Tab)
  mini_map[10]='minibuf-accept'			# C-j (Newline)
  mini_map[13]='minibuf-accept'			# C-m (Return)
  mini_map[14]='minibuf-next-history'		# C-n
  unset mini_map[15]				# C-o
  mini_map[16]='minibuf-previous-history'	# C-p
  unset mini_map[18]				# C-r
  unset mini_map[19]				# C-s

  i=32
  while [ $i -lt 126 ]
  do
    mini_map[$i]='minibuf-self-insert'
    i=$[i + 1]
  done
}

describe-key-briefly()
{
  debug "$FUNCNAME"

  local kmap
  local prefix
  prefix=
  if [ $# = 1 ] ; then
    kmap="$1"
    case $kmap in
      ctrl_x_map) prefix="^X "  ;;
      esc_map)    prefix="ESC " ;;
    esac
  else
    kmap=global_map
  fi

  message "Describe key briefly: "
  IFS=: read -sr -d '' -n 1 c
  char_to_int "$c"
  local key=$?

  local k="$key"
  local desc=$(char_desc $key)
  local binding=$(eval command echo '${'$kmap'[$key]}' )
  if [ ! -z $binding ]; then
    local f=$binding
    local t=$(type -t $f)
    if [ ! -z "$t" ] ; then
      case "$t" in
 	function)
   	  if [ -z ${f#*-map} ] ; then
	    ## @@@ should fix to work for any keymap
  	    describe-key-briefly "${f//-/_}"
  	    return
  	  fi
	  ;;
      esac
      message "'${prefix}${desc}' runs the $t $f"
    else
      message "'${prefix}${desc}' should run the command $f"
    fi
  else
    message "'${prefix}${desc}' is not bound"
  fi
}

funkey()
{
  message ""
  IFS=: read -sr -d '' -n 1 c
  char_to_int "$c"
  key=$?
  case "$c" in
    A)	previous-line	;;
    B)	next-line	;;
    C)	forward-char	;;
    D)	backward-char	;;
  esac
}

esc-map()
{
  local n=$SECONDS
  IFS=: read -sr -d '' -n 1 -t 1 c
  if [ $? != 0 ] ; then
    if [ $[SECONDS - n] -ge 1 ]; then
      message "ESC "
      IFS=: read -sr -d '' -n 1 c
    else
      return
    fi
  fi

  char_to_int "$c"
  key=$?
  if [ ! -z ${esc_map[$key]} ]; then
    if [ ! -z $(type -t ${esc_map[$key]}) ] ; then
      ${esc_map[$key]}
    else
      message "${esc_map[$key]} is not defined"
    fi
  else
    message "ESC $c is not bound"
  fi
}

ctrl-x-map()
{
  message "C-x "
  IFS=: read -sr -d '' -n 1 c
  char_to_int "$c"
  key=$?
  if [ ! -z ${ctrl_x_map[$key]} ]; then
    if [ ! -z $(type -t ${ctrl_x_map[$key]}) ] ; then
      ${ctrl_x_map[$key]}
    else
      message "${ctrl_x_map[$key]} is not defined"
    fi
  else
    message "C-x $c is not bound"
  fi
}

execute-extended-command()
{
  prompt "M-x "
  command="$response"
#  eval "$response"
  typeout "$response"
}

###########################################################################
# Main event loop
###########################################################################

main()
{
  initialize
  trap 'interrupt' INT
  trap 'winch' WINCH

  parse_args "$@"

  local n
  local t
  exit_flag=0
  until [ $exit_flag = 1 ]; do

    # Redraw if we have to
    if [ $need_to_redraw = 1 ]; then
      redraw
    fi
    n=$SECONDS
    IFS=: read -sr -d '' -n 1 -t $timeout c
    if [ $? != 0 ]; then
      # eof, error or timeout
      if [ $[SECONDS - n] -ge $timeout ]; then
	garbage_collect
	continue
      fi
    fi
    char_to_int "$c"
    key=$?
    if [ ! -z ${global_map[$key]} ]; then
      t=$(type -t ${global_map[$key]})
      if [ ! -z "$t" ] ; then
	if [ "$t" = 'function' ]; then
	  ${global_map[$key]}
	else
	  case "$t" in
	    alias|keyword|builtin) ${global_map[$key]}  ;;
	    file)
	      reset_term
	      ${global_map[$key]}
	      init_term
	      need_to_redraw=1
	      ;;
	  esac
	fi
      else
	message "${global_map[$key]} is not defined"
      fi
    else
      message "$c is not bound"
    fi

    # Make sure the modeline is drawn @@@
    if [ $update_modeline = 1 ]; then
      draw_modeline
      moveto $y $x
    fi
  done
}

main "$@"

exit 0
