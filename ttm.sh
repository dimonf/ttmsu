# Define a function rather than a script to use existing tmsu autocmpletion:
# compdef ttmsu=tmsu

# _mpv-curr: custom script which returns full path of currently played file in mpv
#trans-log: custom script which returns date and source recorded previously to log file
#  In my case, log file contains date, url and other details of downloaded torrent
#tmsu: https://github.com/oniony/TMSU

# predefined tmsu tags/values used:
# _date=YYYYMMDD  for date
# _src=[http://example.com|phone|webcamera|...]
# _dir=["roof-installation"|"bd_party"|...]

# tmsu options signature is supported:
#   tmsu tag <filename> tag1 tag2 tag3=tag3_value
# --tags="tag1 tag2 tag3" <filename> or --from=<filename-src> <filename> must be avoided

ttmsu() {
  #the function expects first positional argument 'tag'
  [[ "$1"  != "tag" ]] && echo 'run me with "tag" as first argument!' && return 1
  shift

  #get file name from external program if not found in arguments
  local fpath
  local date
  local src
  local dir
  DRY_RUN=

  _help=$(cat <<EOF
        $0 tag filename|MPV tag1 tag2=value2 OPTIONS
        OPTIONS:
        filename|MPV: MPV is special token, which attempts to get file path from active mpv session
        -n|--dry-run: do nothing, just print details of intended actions
        _date=YYYYMMDD: compulsory. If missed, attempt is made to get it elswhere
        _src=<text>: compulsory. If missed, attempt is made to get it elswhere
        _dir=<text>: optional. If missed, file is moved into standard hierarchy YY/mmdd_<filename>
EOF
)

  local src_fl_found=

  POSITIONAL_ARG=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        echo "$_help" && return 0
         ;;
      MPV)
        [[ -n $src_fl_found ]] && echo "use either MPV or file name; not both" && return 1
        fpath=$(_mpv-curr)
        [[ -z "$fpath" ]] && echo "can not determine file path, exiting" && return 1
        POSITIONAL_ARG+=("$fpath")
        src_fl_found=1
        shift
        ;;
      -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
      _date=*)
        date=${1#*=}
        POSITIONAL_ARG+=("$1")
        shift
        ;;
      _src=*)
        src=${1#*=}
        POSITIONAL_ARG+=("$1")
        shift 
        ;;
      _dir=*)
        dir=${1#*=}
        POSITIONAL_ARG+=("${1// /_}")
        shift 
        ;;
      *)
        if [[ -f "$1" ]]; then
          [[ -n $src_fl_found ]] && echo "use either MPV or file name; not both" && return 1
          fpath="$1"
          src_fl_found=1
        fi
        POSITIONAL_ARG+=("$1")
        shift
        ;;
    esac
  done

  #set -- "${POSITIONAL_ARG[@]}"

  #if path to the file is not specified in arguments, try to get it from running program (mpv)
  if [[ -z "$fpath" ]]; then
    fpath=$(_mpv-curr)
    [[ -z "$fpath" ]] && echo "can not determine file path, exiting" && return 1
    #insert path argument for `tmsu tag` command
    POSITIONAL_ARG=("$fpath" "${POSITIONAL_ARG[@]}")
    #set -- "$fpath" "$@"
  fi
  #get date for a file. priority:
  #  - explicitly provided via tmsu tag (argument)
  #  - torrent log
  #  - file creation date 
  if [[ -z  $date ]]; then
    date=$(trans-log -d "$fpath"|sed 's/[^0-9]//g')
    [[ -n $date ]] || date=$(date -d "$(stat -c %w "$fpath")" +%Y%m%d)
    [[ -z $date ]] && echo "can not determine creation date of the file  $fpath" && return 1
    #insert date argument for `tmsu tag` command
    #set -- "$@" "_date=$date"
    POSITIONAL_ARG=("${POSITIONAL_ARG[@]}" "_date=$date")
  fi

  # get source (origin) of the file. priority:
  # - explicitlyp provided via tmsu tag (argument)
  # - torrent log
  if [[ -z $src ]]; then
    src=$(trans-log "$fpath")
    [[ -z $src ]] && echo "can not determine source reference of the file $fpath" && return 1
    #insert src argument for `tmsu tag` command
    #set -- "$@" "_src=$src"
    POSITIONAL_ARG=("${POSITIONAL_ARG[@]}" "_src=${src// /_}")
  fi
  # first tag file, then move it

  #check date format
  [[ ! $date =~ ^[0-9]{8}$ ]] && echo "ERROR. date value must be in form of YYYYMMDD: $date"  && return 1

  #
  # files are stored either in collection (tmsu tag _dir=home_renovation) or in predefined YY/mmdd_<filename> hierarchy
  local tmsu_root
  tmsu_root=$(tmsu info|awk -F': ' '/^Root path/ { print $2}')
  local dest_path_fn
  dest_path_fn=$(basename "$fpath"|sed 's/ //g')
  if [[ -n $dir ]]; then
    dest_path="$tmsu_root/dirs/$dir/$dest_path_fn"
  else
    #YY/mmdd_<filename>
    dest_path="$tmsu_root/${date:2:2}/${date:4:4}_$dest_path_fn"
  fi

  [[ -n "$DRY_RUN" ]] && printf "%s" "${POSITIONAL_ARG[*]} \n going to copy $fpath to $dest_path" && return 0

  tmsu tag "${POSITIONAL_ARG[@]}" \
    && mkdir -p "$dest_path{%/*}" \
    && cp "$fpath" "$dest_path" \
    && tmsu repair --manual "$fpath" "$dest_path" \
    && printf '%b' "COPIED: $fpath --> $dest_path \nwith tags ${POSITIONAL_ARG[*]:1}"
}
