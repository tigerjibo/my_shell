
function synctmux()   #链接至一个名为 loginTmuxSession 的 tmux 会话
{
    local SESSIONID='loginTmuxSession'

    if ! type tmux >/dev/null 2>&1
    then 
        echo 'Cound not find tmux command, Please install it.'
        return 1
    fi
    if [[ -z "$TMUX" ]]
    then
        export TERM='xterm-256color'
        if ! tmux attach -t $SESSIONID
        then
            if tmux -2 new -s $SESSIONID
            then
                exit $?
            fi
        else
            exit $?
        fi
    fi
    return $?
}

function nosynctmux()
{
    if ! type tmux >/dev/null 2>&1
    then
        echo 'Cound not find tmux command, Please install it.'
        return 1
    fi

    if [[ -z "$TMUX"  ]]
    then
        export TERM='xterm-256color'
        if tmux -2 new
        then
            exit $?
        fi
    fi
    return $?
}

function choosetmuxsession()
{
    local choose='loginTmuxSession'
    if ! type tmux >/dev/null 2>&1
    then
        echo 'Cound not find tmux command, Please install it.'
        return 1
    fi
    
    if [[ -z "$TMUX" ]]
    then 
        if ! tmux ls >/dev/null 2>&1
        then
            export TERM='xterm-256color'
            if tmux -2 new -s 'loginTmuxSession'
            then
                exit $?
            fi
        else
            tmux ls
            echo -n "Please input the tmux session name you choose: "
            read choose
            while true
            do
                if ! tmux attach -t $choose
                then
                    echo -n "Please input the correct session name: "
                    read choose
                else
                    break
                fi
            done
	    exit $?  #若用户退出 tmux 则直接退出 Login 环境
        fi
    fi
    return $?
}

function logintmux()
{
    local choose='n'

    if [[ -z $SSH_CLIENT || -n $TMUX  ]]  #若使用 ssh 登录，则会有 SSH_CLIENT 变量，若当前正在使用tmux，则会有TMUX变量。请用 export -p 查看
    then
        return 0
    fi

    echo -n 'It seems you login with a ssh client, work with tmux? (y/n) '
    read choose
    
    if echo $choose | grep -P [^yY] >/dev/null 2>&1 #若有除 y Y 之外的任何字符则不会继续
    then
        return 0
    fi

    cat <<EOF
    How do you want to use tmux?
    (1) Try to attach a common session (loginTmuxSession), so operations are synchronized display.
    (2) Choose an existing tmux session.
    (3) Use a different session.
    (4) I do not want to use tmux anymore.
EOF

    while true
    do
	    echo -n 'Input your choose (1-4): '
        read choose
        
	    echo $choose | grep -P '[^1-4]' >/dev/null 2>&1
        if [[ 0 -eq $? || $choose -lt 1 || $choose -gt 5 ]]
        then
            continue
        fi
    break
    done

    case $choose in 
        1)
            synctmux
            ;;
        2)
            choosetmuxsession
            ;;
        3)
            nosynctmux
            ;;
        4)
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

#set -x
logintmux
