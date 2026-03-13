gdc() {
  emulate -L zsh

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Not a git repository"
    return 1
  }

  local mode="head"
  local revspec=""
  local show_untracked=1
  local name_only=0
  local sort_key=""
  local top_n=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--cached|-s|--staged)
        mode="cached"
        show_untracked=0
        shift
        ;;
      -w|--worktree)
        mode="worktree"
        show_untracked=1
        shift
        ;;
      -n|--name-only)
        name_only=1
        shift
        ;;
      -S|--sort)
        shift
        [[ $# -gt 0 ]] || {
          echo "gdc: missing value for --sort"
          return 1
        }
        case "$1" in
          add|del|file)
            sort_key="$1"
            ;;
          *)
            echo "gdc: invalid sort key: $1 (expected: add|del|file)"
            return 1
            ;;
        esac
        shift
        ;;
      -t|--top)
        shift
        [[ $# -gt 0 ]] || {
          echo "gdc: missing value for --top"
          return 1
        }
        [[ "$1" == <-> ]] || {
          echo "gdc: --top expects a positive integer"
          return 1
        }
        top_n="$1"
        shift
        ;;
      -h|--help)
        cat <<'EOH'
Usage:
  gdc [options] [<rev-or-range>]

Modes:
  -c, --cached        Show staged changes only
  -s, --staged        Same as --cached
  -w, --worktree      Show unstaged changes + untracked files
      (default)       Show diff vs HEAD (staged + unstaged) + untracked files

Display options:
  -n, --name-only     Show only file names
  -S, --sort KEY      Sort by: add | del | file
  -t, --top N         Show only the first N rows after sorting/current order
  -h, --help          Show this help

Examples:
  gdc
  gdc -c
  gdc -w
  gdc HEAD~1
  gdc HEAD~3..HEAD
  gdc -S add
  gdc -S del -t 20
  gdc -n -S file
EOH
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "gdc: unknown option: $1"
        return 1
        ;;
      *)
        if [[ -z "$revspec" ]]; then
          revspec="$1"
          mode="revspec"
          show_untracked=1
          shift
        else
          echo "gdc: unexpected extra argument: $1"
          return 1
        fi
        ;;
    esac
  done

  local tmp_raw tmp_view
  tmp_raw="$(mktemp)" || return 1
  tmp_view="$(mktemp)" || {
    rm -f "$tmp_raw"
    return 1
  }

  {
    case "$mode" in
      head)
        git diff --numstat HEAD
        ;;
      cached)
        git diff --cached --numstat
        ;;
      worktree)
        git diff --numstat
        ;;
      revspec)
        git diff --numstat "$revspec"
        ;;
    esac

    if [[ "$show_untracked" -eq 1 ]]; then
      git ls-files --others --exclude-standard -z |
      while IFS= read -r -d '' file; do
        [[ -f "$file" ]] || continue
        printf '%s\t0\t%s\n' "$(wc -l < "$file" 2>/dev/null | tr -d '[:space:]')" "$file"
      done
    fi
  } > "$tmp_raw"

  if [[ -n "$sort_key" ]]; then
    case "$sort_key" in
      add)
        LC_ALL=C sort -t $'\t' -k1,1nr -k2,2nr -k3,3 "$tmp_raw" > "$tmp_view"
        ;;
      del)
        LC_ALL=C sort -t $'\t' -k2,2nr -k1,1nr -k3,3 "$tmp_raw" > "$tmp_view"
        ;;
      file)
        LC_ALL=C sort -t $'\t' -k3,3 "$tmp_raw" > "$tmp_view"
        ;;
    esac
  else
    cp "$tmp_raw" "$tmp_view"
  fi

  if [[ -n "$top_n" ]]; then
    head -n "$top_n" "$tmp_view" > "${tmp_view}.top"
    mv "${tmp_view}.top" "$tmp_view"
  fi

  if [[ "$name_only" -eq 1 ]]; then
    awk -F '\t' '
      BEGIN {
        blue  = "\033[34m"
        reset = "\033[0m"
      }
      NF >= 3 && $3 != "" {
        file = $3
        dir = ""
        base = file

        if (match(file, /.*\//)) {
          dir = substr(file, 1, RLENGTH)
          base = substr(file, RLENGTH + 1)
        }

        printf "%s" blue "%s" reset "\n", dir, base
      }
    ' "$tmp_view"
  else
    awk -F '\t' '
      BEGIN {
        green   = "\033[32m"
        red     = "\033[31m"
        blue    = "\033[34m"
        magenta = "\033[35m"
        bold    = "\033[1m"
        reset   = "\033[0m"

        add_sum = 0
        del_sum = 0
        n = 0
        maxw = 3
        filew = 4
      }

      NF < 3 || $3 == "" { next }

      {
        adds[++n] = $1
        dels[n]   = $2
        files[n]  = $3

        if ($1 ~ /^[0-9]+$/) {
          add_sum += $1
          if (length($1) > maxw) maxw = length($1)
        }
        if ($2 ~ /^[0-9]+$/) {
          del_sum += $2
          if (length($2) > maxw) maxw = length($2)
        }
        if (length($3) > filew) filew = length($3)
      }

      END {
        if (length(add_sum "") > maxw) maxw = length(add_sum "")
        if (length(del_sum "") > maxw) maxw = length(del_sum "")

        sep_num  = sprintf("%" maxw "s", "")
        sep_file = sprintf("%" filew "s", "")
        gsub(/ /, "-", sep_num)
        gsub(/ /, "-", sep_file)

        printf magenta bold "%" maxw "s  %" maxw "s  %-" filew "s\n" reset, "ADD", "DEL", "FILE"
        printf magenta "%s  %s  %s\n" reset, sep_num, sep_num, sep_file

        for (i = 1; i <= n; i++) {
          file = files[i]
          dir = ""
          base = file

          if (match(file, /.*\//)) {
            dir = substr(file, 1, RLENGTH)
            base = substr(file, RLENGTH + 1)
          }

          printf green "%" maxw "s" reset "  " red "%" maxw "s" reset "  %s" blue "%s" reset "\n",
                 adds[i], dels[i], dir, base
        }

        if (n > 1) {
          printf magenta "%s  %s  %s\n" reset, sep_num, sep_num, sep_file
          printf green "%" maxw "d" reset "  " red "%" maxw "d" reset "  %s\n", add_sum, del_sum, "TOTAL"
        }
      }
    ' "$tmp_view"
  fi

  local rc=$?
  rm -f "$tmp_raw" "$tmp_view" "${tmp_view}.top" 2>/dev/null
  return $rc
}
