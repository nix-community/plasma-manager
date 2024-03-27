# there could be a bash shebang to ${pkgs.bash}/bin/bash here

# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux/5947802#5947802
RED='\033[0;31m'

# https://stackoverflow.com/questions/2924697/how-does-one-output-bold-text-in-bash/2924755#2924755
BOLD=$(tput bold)
NORMAL=$(tput sgr0)


# # =====================================
# #     CHECK THE NUMBER OF ARGS
# #
# # https://www.baeldung.com/linux/bash-check-script-arguments

if [[ "$#" -ne 1 ]]; then
  # https://stackoverflow.com/questions/3005963/how-can-i-have-a-newline-in-a-string-in-sh/3182519#3182519
  >&2 printf "%sIncorrect number of arguments.%s Expected one: The name of the theme that should not already be in use" "${RED}${BOLD}" "${NORMAL}${RED}"
  exit 1
fi

THEMENAME=$1


# =====================================
#      GO THROUGH THE THEMES
#
# reference the XDG dir as proposed in https://github.com/nix-community/home-manager/pull/4594#issuecomment-1774024207

THEME_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/org.kde.syntax-highlighting/themes/"

# TODO and symlinks! (or: skip over dirs)
find "${THEME_DIR}" \( -type f -o -type l \) | while read -r themefile; do
  THIS_THEMENAME=$(jq -r .metadata.name "${themefile}")

  if [[ "${THIS_THEMENAME}" == "${themefile}" ]]; then
    # make sure to not look at symbolic links to the nix store
    # https://stackoverflow.com/questions/17918367/linux-shell-verify-whether-a-file-exists-and-is-a-soft-link/17918442#17918442
    # https://stackoverflow.com/questions/2172352/in-bash-how-can-i-check-if-a-string-begins-with-some-value/2172367#2172367
    if [[ ! ( -L "${themefile}"  &&  $(readlink -f "${themefile}") == /nix/store/* ) ]]; then
      >&2 printf "%s In %s there is already a theme with the name %s (%s).%s You could rename the theme given in config.programs.kate.editor.theme.src by changing the value for metadata.name inside the theme." "${RED}${BOLD}" "${THEME_DIR}" "${THEMENAME}" "${themefile}" "${NORMAL}${RED}"
      exit 1 # even on dryrun
     fi
  fi
done
