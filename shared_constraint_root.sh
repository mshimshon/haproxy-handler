if [ "$EUID" -ne 0 ]; then
  echo "This installer must be run as root"
  exit 1
fi
