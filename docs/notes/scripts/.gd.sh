gd() {
    emulate -L zsh
    setopt local_options pipe_fail no_aliases

    command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        printf '%s\n' 'Not a git repository'
        return 1
    }

    local mode="head"
    local revspec=""
    local show_untracked=1
    local name_only=0
    local sort_key=""
    local top_n=""
    local tmp_raw=""
    local tmp_view=""
    local tmp_top=""
    local rc=0

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
                    printf '%s\n' 'gd: missing value for --sort'
                    return 1
                }
                case "$1" in
                    add|del|file)
                        sort_key="$1"
                        ;;
                    *)
                        printf 'gd: invalid sort key: %s (expected: add|del|file)\n' "$1"
                        return 1
                        ;;
                esac
                shift
                ;;
            -t|--top)
                shift
                [[ $# -gt 0 ]] || {
                    printf '%s\n' 'gd: missing value for --top'
                    return 1
                }
                [[ "$1" == <-> ]] || {
                    printf '%s\n' 'gd: --top expects a positive integer'
                    return 1
                }
                top_n="$1"
                shift
                ;;
            -h|--help)
                cat <<'EOH'
Usage:
  gd [options] [<rev-or-range>]

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
  gd
  gd -c
  gd -w
  gd 'HEAD~1'
  gd 'HEAD~3..HEAD'
  gd -S add
  gd -S del -t 20
  gd -n -S file
EOH
                return 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                printf 'gd: unknown option: %s\n' "$1"
                return 1
                ;;
            *)
                if [[ -z "$revspec" ]]; then
                    revspec="$1"
                    mode="revspec"
                    show_untracked=1
                    shift
                else
                    printf 'gd: unexpected extra argument: %s\n' "$1"
                    return 1
                fi
                ;;
        esac
    done

    if [[ $# -gt 0 ]]; then
        printf 'gd: unexpected extra argument: %s\n' "$1"
        return 1
    fi

    tmp_raw="$(command mktemp)" || return 1
    tmp_view="$(command mktemp)" || {
        command rm -f -- "$tmp_raw"
        return 1
    }
    tmp_top="${tmp_view}.top"

    {
        case "$mode" in
            head)
                command git diff --numstat HEAD
                ;;
            cached)
                command git diff --cached --numstat
                ;;
            worktree)
                command git diff --numstat
                ;;
            revspec)
                command git diff --numstat "$revspec"
                ;;
        esac

        if [[ "$show_untracked" -eq 1 ]]; then
            command git ls-files --others --exclude-standard -z |
            while IFS= read -r -d '' file; do
                [[ -f "$file" ]] || continue
                printf '%s\t0\t%s\n' "$(command wc -l < "$file" 2>/dev/null | command tr -d '[:space:]')" "$file"
            done
        fi
    } > "$tmp_raw"
    rc=$?

    if (( rc == 0 )); then
        if [[ -n "$sort_key" ]]; then
            case "$sort_key" in
                add)
                    LC_ALL=C command sort -t $'\t' -k1,1nr -k2,2nr -k3,3 -- "$tmp_raw" > "$tmp_view"
                    rc=$?
                    ;;
                del)
                    LC_ALL=C command sort -t $'\t' -k2,2nr -k1,1nr -k3,3 -- "$tmp_raw" > "$tmp_view"
                    rc=$?
                    ;;
                file)
                    LC_ALL=C command sort -t $'\t' -k3,3 -- "$tmp_raw" > "$tmp_view"
                    rc=$?
                    ;;
            esac
        else
            command cp -- "$tmp_raw" "$tmp_view"
            rc=$?
        fi
    fi

    if (( rc == 0 )) && [[ -n "$top_n" ]]; then
        command head -n "$top_n" -- "$tmp_view" > "$tmp_top"
        rc=$?
        if (( rc == 0 )); then
            command mv -- "$tmp_top" "$tmp_view"
            rc=$?
        fi
    fi

    if (( rc == 0 )); then
        if [[ "$name_only" -eq 1 ]]; then
            command awk -F '\t' '
                BEGIN {
                    gray  = "\033[90m"
                    green = "\033[32m"
                    red   = "\033[31m"
                    blue  = "\033[34m"
                    reset = "\033[0m"
                }

                function is_positive_num(value) {
                    return value ~ /^[0-9]+$/ && value > 0
                }

                function file_color(adds, dels, add_present, del_present) {
                    add_present = is_positive_num(adds)
                    del_present = is_positive_num(dels)

                    if (add_present && del_present) {
                        return blue
                    }
                    if (add_present) {
                        return green
                    }
                    if (del_present) {
                        return red
                    }
                    return blue
                }

                NF >= 3 && $3 != "" {
                    file = $3
                    dir = ""
                    base = file

                    if (match(file, /.*\//)) {
                        dir = substr(file, 1, RLENGTH)
                        base = substr(file, RLENGTH + 1)
                    }

                    printf "%s%s%s%s%s\n", gray, dir, reset, file_color($1, $2), base reset
                }
            ' "$tmp_view"
            rc=$?
        else
            command awk -F '\t' '
                BEGIN {
                    gray    = "\033[90m"
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
                    add_files = 0
                    del_files = 0
                    change_files = 0
                }

                function is_positive_num(value) {
                    return value ~ /^[0-9]+$/ && value > 0
                }

                function display_count(value) {
                    return value == 0 ? "" : value
                }

                function append_summary(summary, text) {
                    return summary == "" ? text : summary ", " text
                }

                function file_color(adds, dels, add_present, del_present) {
                    add_present = is_positive_num(adds)
                    del_present = is_positive_num(dels)

                    if (add_present && del_present) {
                        return blue
                    }
                    if (add_present) {
                        return green
                    }
                    if (del_present) {
                        return red
                    }
                    return blue
                }

                NF < 3 || $3 == "" { next }

                {
                    adds[++n] = $1
                    dels[n] = $2
                    files[n] = $3

                    add_present = is_positive_num($1)
                    del_present = is_positive_num($2)

                    if (add_present && del_present) {
                        change_files += 1
                    } else if (add_present) {
                        add_files += 1
                    } else if (del_present) {
                        del_files += 1
                    }

                    if ($1 ~ /^[0-9]+$/) {
                        add_sum += $1
                        if (length($1) > maxw) {
                            maxw = length($1)
                        }
                    }
                    if ($2 ~ /^[0-9]+$/) {
                        del_sum += $2
                        if (length($2) > maxw) {
                            maxw = length($2)
                        }
                    }
                    if (length($3) > filew) {
                        filew = length($3)
                    }
                }

                END {
                    add_sum_display = display_count(add_sum)
                    del_sum_display = display_count(del_sum)

                    if (length(add_sum "") > maxw) {
                        maxw = length(add_sum "")
                    }
                    if (length(del_sum "") > maxw) {
                        maxw = length(del_sum "")
                    }

                    sep_num = sprintf("%" maxw "s", "")
                    sep_file = sprintf("%" filew "s", "")
                    gsub(/ /, "-", sep_num)
                    gsub(/ /, "-", sep_file)

                    printf magenta "%s  %s  %s\n" reset, sep_num, sep_num, sep_file
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

                        add_display = display_count(adds[i])
                        del_display = display_count(dels[i])
                        color = file_color(adds[i], dels[i])

                        printf green "%" maxw "s" reset "  " red "%" maxw "s" reset "  %s%s%s%s%s\n", \
                               add_display, del_display, gray, dir, reset, color, base reset
                    }

                    printf magenta "%s  %s  %s\n" reset, sep_num, sep_num, sep_file

                    summary = ""
                    if (add_files > 0) {
                        summary = append_summary(summary, green sprintf("add %d files", add_files) reset)
                    }
                    if (del_files > 0) {
                        summary = append_summary(summary, red sprintf("del %d files", del_files) reset)
                    }
                    if (change_files > 0) {
                        summary = append_summary(summary, blue sprintf("change %d files", change_files) reset)
                    }

                    total_label = summary == "" ? "TOTAL" : "TOTAL (" summary ")"
                    printf green "%" maxw "s" reset "  " red "%" maxw "s" reset "  %s\n", add_sum_display, del_sum_display, total_label
                    printf magenta "%s  %s  %s\n" reset, sep_num, sep_num, sep_file
                }
            ' "$tmp_view"
            rc=$?
        fi
    fi

    command rm -f -- "$tmp_raw" "$tmp_view" "$tmp_top" 2>/dev/null
    return $rc
}
