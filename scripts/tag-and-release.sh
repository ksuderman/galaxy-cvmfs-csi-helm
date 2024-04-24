#!/usr/bin/env bash

# Determine our name for use in the help message.
SCRIPT=$(basename $(realpath $0))

# ANSI color codes for the console.
reset="\033[0m"
bold="\033[1m"
ital="\033[3m" # does not work on OS X

# Function used to highlight text.
function hi() {
    echo -e "$bold$@$reset"
}

# The last version that was tagged.
LATEST=$(git describe --tags `git rev-list --tags --max-count=1` | tr -d 'v')

# Date since the last release.  We will search for commits newer than this.
SINCE=$(git log -1 --format=%as v$LATEST)

function help() {
    less -RX << EOF

$(hi NAME)
    $SCRIPT

$(hi DESCRIPTION)
    Tags and generates a GitHub release for all commits that have "Automatic" in the
    commit messages.  These will be the commits that were generated by the packaging
    GitHub action.

$(hi SYNOPSIS)
    $SCRIPT --since DATE --latest TAG_NAME

$(hi OPTIONS)
    -l|--latest   the tag name of the last commit that was tagged. Default to $LATEST
    -s|--since    search the git log after this date (YYYY-MM-DD). Defaults to $SINCE
    -h|--help     prints this help message and exits

    The $(hi --latest) and $(hi --since) fields will be determined from the Git log
    if they are not provided.

Press $(hi Q) to quit this help.

EOF
}

while [[ $# > 0 ]] ; do
    case $1 in
      -l|--latest)
        LATEST=$2
        shift
        ;;
      -s|--since)
        SINCE=$2
        shift
        ;;
      -h|--help|help)
        help
        exit
        ;;
      *)
        echo "Invalid option $1"
        echo "Run $(hi $SCRIPT help) for usage information"
        exit
    esac
    shift
done
PREVIOUS="v$LATEST"

# Search the git log for commits that did an Automatic version bump.
git log --oneline --grep=Automatic --since=$SINCE | awk '{print $1,$NF}' | grep -v $LATEST | tail -r | while read -r line ; do
	commit=$(echo $line | awk '{print $1}')
	tag=v$(echo $line | awk '{print $2}')
	# Get the actual date the commit was made
	export GIT_COMMITTER_DATE=$(git show --format=%aD $commit | head -1)
	# Tag the commit
	echo "Tagging $commit as $tag $GIT_COMMITTER_DATE"
	git checkout $commit
	git tag -a -m "Automatic tagging of $tag" $tag
	git push origin $tag
	# Generate the release.
	gh release create $tag --generate-notes --latest --notes-start-tag $PREVIOUS
	PREVIOUS=$tag
done
git checkout master
echo "Done."
