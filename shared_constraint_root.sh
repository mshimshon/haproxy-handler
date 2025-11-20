echo "Executed as $EUID"
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Please run as root or with sudo"
    return 1
fi