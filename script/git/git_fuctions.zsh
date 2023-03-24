#!/usr/bin/zsh

# https://github.com/bahmutov/git-branches/blob/master/branches.sh
function list_branch_with_description() {
  branches=`git branch --list $1`

  # requires git > v.1.7.9

  # you can set branch's description using command
  # git branch --edit-description
  # this opens the configured text editor, enter message, save and exit
  # if one editor does not work (for example Sublime does not work for me)
  # try another one, like vi

  # you can see branch's description using
  # git config branch.<branch name>.description

  while read -r branch; do
    # git marks current branch with "* ", remove it
    clean_branch_name=${branch//\*\ /}
    # replace colors
    clean_branch_name=`echo $clean_branch_name | tr -d '[:cntrl:]' | sed -E "s/\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"`
    # replace symbolic-ref like `HEAD -> master`
    clean_branch_name=`echo $clean_branch_name | sed -E "s/^.+ -> //g"`

    description=`git config branch.$clean_branch_name.description`
    if [[ "${branch:0:1}" = "*" ]]; then
      printf "$branch $description\n"
    else
      printf "  $branch $description\n"
    fi
  done <<< "$branches"

  # example output
  # $ ./branches.sh
  # * master        this is master branch
  # one             this is simple branch for testing
}


function git_branch() {
  # @see [git-branch](https://git-scm.com/docs/git-branch)
  if [[ "$@" = "" ]]; then
    list_branch_with_description "--color"
  elif [[ "$@" =~ "--color" || "$@" =~ "--no-color" ]]; then
    list_branch_with_description "$@"
  else
    branch_operation_result=`git branch $@`
    printf "$branch_operation_result\n"
  fi
}

