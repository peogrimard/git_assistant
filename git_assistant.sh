#!/bin/bash
#
# git_assistant : manage git repos - git://github.com/peogrimard/git_assistant.git

# jq must be installed
if [[ ! -x /usr/bin/jq ]]; then
    echo "Looks like 'jq' is not installed."
    echo "Jq is a command-line JSON processor https://stedolan.github.io/jq/"
    echo "This is a required dependency, please install to continue."
fi

auth=false
function AUTH () {

    case $1 in
        decrypt)
            if [[ ! -s .token ]]; then
                
                echo "No Auth Token found ..."
                echo
                AUTH encrypt
            fi
            if [[ "$auth" =  false ]]; then 

                [[ ! -s ./.username ]] && read -p "Enter your GitHub username: " username && echo "$username" > .username
                echo -n "Enter Auth Token Password: "
                read -s password
                echo
                unHash="$(cat .token | openssl enc -aes-256-cbc -pbkdf2 -d -a -k $password)"
                password=''
                authToken="$unHash"
                auth=true
            fi
            ;;

        encrypt)
            echo "Encrypting Auth Token"
            echo
            echo "Please enter your Auto Token provided by GitHub."
            echo "If you don't have one, please visit https://github.com/settings/tokens"
            echo
            read -p "Auth Token: " clearAuthToken
            echo
            echo "$clearAuthToken" | openssl enc -aes-256-cbc -pbkdf2 -a -out .token
            clearAuthToken=''
            echo
            echo "Successfully created an encrypted Auth Token"
            echo
            ;;
        *)
            ;;
esac
}

function LIST () {

    clear
    echo "List all repository"
    echo
    echo
    
    AUTH decrypt

    printf "\e[1;37m%-8s%-10s\e[0m\n\n" "Status" "Full name"

    curl -s -X GET -H "Authorization: token $authToken" --data '{"visibility":"all","sort":"full_name","direction":"asc"}' https://api.github.com/user/repos | jq '[.[] | {Full_name: .full_name, Private: .private,}]' | jq -r '.[] | "\(.Private)\t\(.Full_name)"' | sed 's/true/PRIVATE/g' | sed 's/false/PUBLIC/g' | sort -g
    echo
}

function CREATE () {

    echo  "Create new repository"
    echo
    echo

    while [[ -z $name ]]; do
        read -p "Name : " name
    done

    read -p "Description [] : " description
    read -p "Homepage URL [] : " homepage
    read -p "Make private? true/false [true] : " private
    private=${private:-'true'}
    echo
    
    data=$(jq --arg name "$name" --arg private "$private" --arg description "$description" --arg homepage "$homepage" --arg private "$private" -nc '{name:$name,private:$private,description:$description,homepage:$homepage,private:$private}')

    read -rp "Create new repository ? y/n [y]: " create
    create=${create:-'y'}

    if [[ $create = y ]]; then

        echo "Sending request ..."
        echo

        AUTH decrypt
        echo

        # curl -s -H "Authorization: token $authToken" --data "$data" https://api.github.com/user/repos --output .git_assistant.txt
        response=`curl -s -H "Authorization: token $authToken" --data "$data" -o /tmp/git_assistant -w "%{http_code}\n" https://api.github.com/user/repos`
        RESPONSE_HANDLER "$response"

    else
        echo "Repository not created"
        echo

    fi

}

function DELETE () {

    echo "Delete repository"
    echo
    echo

    read -p "Owner [`cat .username`] : " owner
    owner=${owner:-"`cat .username`"}
    read -p "Reposiory : " repo
    echo
    read -p "Delete https://api.github.com/repos/$owner/$repo ? y/n [n] : " yn
    yn=${yn:-'n'}
    [[ "$yn" == "n" ]] && echo "Not deleting" && exit
    
    AUTH decrypt
    echo
    
    response=`curl -s -X DELETE -H "Authorization: token $authToken" -o /tmp/git_assistant -w "%{http_code}\n" https://api.github.com/repos/$owner/$repo`
    RESPONSE_HANDLER "$response"

}

function RESPONSE_HANDLER () {

    printf "\n\n"

    response=$1
    case $response in
        204)
            echo "Success ($response)"
            # echo /tmp/git_assistant | jq .clone_url

            ;;
        404)
            echo "Not found ($response)"
            # echo /tmp/git_assistant | jq .message
            ;;
        *)
            echo "Respose : $response"
            ;;
    esac
}

clear 
cat <<- 'title'
  ____ _ _   _   _       _          _            _     _              _   
 / ___(_) |_| | | |_   _| |__      / \   ___ ___(_)___| |_ __ _ _ __ | |_ 
| |  _| | __| |_| | | | | '_ \    / _ \ / __/ __| / __| __/ _` | '_ \| __|
| |_| | | |_|  _  | |_| | |_) |  / ___ \\__ \__ \ \__ \ || (_| | | | | |_ 
 \____|_|\__|_| |_|\__,_|_.__/  /_/   \_\___/___/_|___/\__\__,_|_| |_|\__|
                             git://github.com/peogrimard/git_assistant.git


title

PS3="Please select : "
select i in List Create Delete Exit
do
  case $i in
    List) LIST;;
    Create) CREATE;;
    Delete) DELETE;;
    Exit) exit;;
  esac
done