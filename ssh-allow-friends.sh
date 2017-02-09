#!/bin/bash

function print_help()
{
   echo ""
   echo "    Temporarily allow a ssh login using friends public key"
   echo ""
   echo "Usage:"
   echo "    $0 [options] <friend_user_name>"
   echo ""
   echo "[options]"
   echo "    -h | --help     Print this help;"
   echo "    -g | --github   Select Github as public key server."
   echo ""
   echo "<friend_user_name>"
   echo "    It is the username used to download keys from selected server."
   echo ""
   echo "Advanced example:"
   echo ""
   echo "    Allow user \`john-doe\` from Github to login as user \`myself\`:"
   echo "    sudo -H -u myself $0 --github john-doe"
   echo ""
}

function print_usage()
{
    echo "Usage example: $0 --github <user_name>"
}

#define vars
GITHUB=0
USERNAME=''
USERKEY=''
SERVICENAME=''
LOCALIPADDRESS=''

#test dependencies
getopt --test >/dev/null
if [[ $? -ne 4 ]]; then
    echo "$0: \`getopt --test\` failed in this environment."
    exit 1
fi

curl --help >/dev/null
if [[ $? -ne 0  ]]; then
    echo "$): \`curl --help\` failed in this environment."
    exit 1
fi

IP_CMD=$(which ip 2>/dev/null)
if [[ $? -ne 0  ]]; then
    echo "$0: ip command not available."
    exit 1
fi

SSH_KEYGEN_CMD=$(which ssh-keygen 2>/dev/null)
if [[ $? -ne 0  ]]; then
    echo "$0: ssh-keygen command not availabe."
    exit -1
fi

#Parse arguments
SHORT=gh
LONG=github,help

PARSED=`getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@"`
if [[ $? -ne 0  ]]; then
    echo "$0: Invalid parameters."
    print_usage
    exit 2
fi
eval set -- "$PARSED"

while true; do
    case "$1" in
        -h | --help)
            print_help
            exit 0
            ;;
        -g | --github)
            GITHUB=1
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

if [[ $# -ne 1 ]]; then
    echo "$0: A single user name is required."
    print_usage
    exit 4
fi

USERNAME=$1

#Get user keys from server
github_download_key()
{
    SERVICENAME='github'
    USERKEY=`curl -s https://github.com/$USERNAME.keys`
    USERKEY=`echo $USERKEY | grep -v '^#'`

    echo $USERKEY | grep "Not Found"
    if [[ $? == 1]]; then
        echo "User $USERNAME not found in Github."
        exit 5
    fi

    if [[ -z $USERKEY  ]]; then
        echo "User $USERNAME has not keys in Github."
        exit 5
    fi
}

if [[ $GITHUB -eq 1 ]]; then
    github_download_key
else
    echo "$0: No service selected."
    print_usage
    exit 5
fi


#check keys integrity
TMP_KEY_FILE=/tmp/.ssh-allow-friend.$USERNAME-$USER-$SERVICENAME.keys
echo $USERNAME > $TMP_KEY_FILE
ssh-keygen -l -f $TMP_KEY_FILE >/dev/null
if [[ $? -ne 0 ]]; then
    echo "$0: Download key is invaild."
    exit 6
fi
rm -f $TMP_KEY_FILE

#Get local ip address
# 关于 awk 中的 gsub 函数请参考：http://blog.itpub.net/27042095/viewspace-1096916/
LOCALIPADDRESS=$($IP_CMD -o addr show scope global | awk '{gsub(/\/m.*/,"",$4); print $4}')
echo "Acquired key for user $USERNAME from $SERVICENAME,"
echo "your firends is now available to login via ssh using: "
echo "$LOCALIPADDRESS" | while read a; do echo  "    ssh $USER@$a"; done
echo ""
echo "Login authorization will be ceased after this program"
echo "terminates"
echo "Please ^C to exit."

function setup()
{
    (
        block 200
        mkdir -p $HOME/.ssh/
        echo "$USERKEY" >> $HOME/.ssh/authorized_keys
    ) 200>/tmp/.ssh-allow-friend.$USER.lock
}

function teardown()
{
    (
        flock 200
        #remove key from file, or the entire file if empty
        if grep -v "$USERKEY" $HOME/.ssh/authorized_keys > $HOME/.ssh/tmp; then
            cat $HOME/.ssh/tmp > $HOME/.ssh/authorized_keys && rm -f $HOME/.ssh/tmp;
        else
            rm $HOME/.ssh/authorized_keys && rm $HOME/.ssh/tmp;
        fi
    ) 200>/tmp/.ssh-allow-friend.$USER.lock
}

trap "teardown; exit 0" SIGHUP SIGINT SIGTERM
setup
sleep infinity &
wait







