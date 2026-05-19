# Jump to a frecent directory via zshz + fzf.
j() {
    [ $# -gt 0 ] && zshz "$*" && return
    cd "$(zshz -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')"
}

# https://github.com/bahmutov/git-branches/blob/master/branches.sh
list_branch_with_description() {
    branches=$(git branch --list "$1")
    while read -r branch; do
        clean_branch_name=${branch//\*\ /}
        clean_branch_name=$(echo "$clean_branch_name" | tr -d '[:cntrl:]' | sed -E "s/\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
        clean_branch_name=$(echo "$clean_branch_name" | sed -E "s/^.+ -> //g")
        description=$(git config "branch.$clean_branch_name.description")
        if [[ "${branch:0:1}" = "*" ]]; then
            printf "%s %s\n" "$branch" "$description"
        else
            printf "  %s %s\n" "$branch" "$description"
        fi
    done <<< "$branches"
}

git_branch() {
    if [[ "$*" = "" ]]; then
        list_branch_with_description "--color"
    elif [[ "$*" =~ "--color" || "$*" =~ "--no-color" ]]; then
        list_branch_with_description "$*"
    else
        branch_operation_result=$(git branch "$@")
        printf "%s\n" "$branch_operation_result"
    fi
}
