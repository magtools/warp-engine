#!/bin/bash

    # IMPORT HELP

    . "$PROJECTPATH/.warp/bin/mysql_help.sh"

function mysql_info()
{

    if ! warp_check_env_file ; then
        warp_message_error "file not found $(basename $ENVIRONMENTVARIABLESFILE)"
        exit
    fi; 

    DATABASE_NAME=$(warp_env_read_var DATABASE_NAME)
    DATABASE_USER=$(warp_env_read_var DATABASE_USER)
    DATABASE_PASSWORD=$(warp_env_read_var DATABASE_PASSWORD)
    DATABASE_ROOT_PASSWORD=$(warp_env_read_var DATABASE_ROOT_PASSWORD)
    DATABASE_BINDED_PORT=$(warp_env_read_var DATABASE_BINDED_PORT)
    MYSQL_CONFIG_FILE=$(warp_env_read_var MYSQL_CONFIG_FILE)
    MYSQL_VERSION=$(warp_env_read_var MYSQL_VERSION)
    MODE_SANDBOX=$(warp_env_read_var MODE_SANDBOX)

    if [ "$MODE_SANDBOX" = "Y" ] || [ "$MODE_SANDBOX" = "y" ] ; then 
        DATABASE_USER=null
        DATABASE_PASSWORD=null
    fi

    if [ ! -z "$DATABASE_ROOT_PASSWORD" ]
    then
        warp_message ""
        warp_message_info "* MySQL"
        warp_message "Database Name:              $(warp_message_info $DATABASE_NAME)"
        warp_message "Host: (container)           $(warp_message_info mysql)"
        warp_message "Username:                   $(warp_message_info $DATABASE_USER)"
        warp_message "Password:                   $(warp_message_info $DATABASE_PASSWORD)"
        warp_message "Root user:                  $(warp_message_info root)"
        warp_message "Root password:              $(warp_message_info $DATABASE_ROOT_PASSWORD)"
        warp_message "Binded port (host):         $(warp_message_info $DATABASE_BINDED_PORT)"
        warp_message "MySQL version:              $(warp_message_info $MYSQL_VERSION)"
        warp_message "my.cnf location:            $(warp_message_info $PROJECTPATH/.warp/docker/config/mysql/my.cnf)"
        warp_message "Other config files:         $(warp_message_info $MYSQL_CONFIG_FILE)"
        warp_message "Dumps folder (host):        $(warp_message_info $PROJECTPATH/.warp/docker/dumps)" 
        warp_message "Dumps folder (container):   $(warp_message_info /dumps)"
        warp_message ""
        warp_message_warn " - prevent to use 127.0.0.1 or localhost as database host.  Instead of 127.0.0.1 use: $(warp_message_bold 'mysql')"
        warp_message ""
    fi
}

warp_mysql_flavor() {
    MYSQL_DOCKER_IMAGE=$(warp_env_read_var MYSQL_DOCKER_IMAGE)
    case "$MYSQL_DOCKER_IMAGE" in
        mariadb:*|*/mariadb:*|*mariadb*)
            echo "mariadb"
            ;;
        *)
            echo "mysql"
            ;;
    esac
}

warp_mysql_client_bin() {
    if [ "$(warp_mysql_flavor)" = "mariadb" ]; then
        echo "mariadb"
    else
        echo "mysql"
    fi
}

warp_mysql_dump_bin() {
    if [ "$(warp_mysql_flavor)" = "mariadb" ]; then
        echo "mariadb-dump"
    else
        echo "mysqldump"
    fi
}

function mysql_connect()
{

    if [ "$1" = "-h" ] || [ "$1" = "--help" ]
    then
        mysql_connect_help
        exit 1
    fi;

    if [ $(warp_check_is_running) = false ]; then
        warp_message_error "The containers are not running"
        warp_message_error "please, first run warp start"

        exit 1;
    fi

    DATABASE_ROOT_PASSWORD=$(warp_env_read_var DATABASE_ROOT_PASSWORD)

    MYSQL_CLIENT_BIN=$(warp_mysql_client_bin)
    docker-compose -f $DOCKERCOMPOSEFILE exec mysql bash -c "CMD=\"$MYSQL_CLIENT_BIN\"; command -v \"\$CMD\" >/dev/null 2>&1 || CMD=\"mysql\"; \"\$CMD\" -uroot -p$DATABASE_ROOT_PASSWORD"
}

function mysql_update_db()
{

    DOCKER_PRIVATE_REGISTRY=$(warp_env_read_var DOCKER_PRIVATE_REGISTRY)

    if [ -z "$DOCKER_PRIVATE_REGISTRY" ] ; then
        warp_message_error "this command only work with private db registry"

        exit 1;
    fi

    warp_message "This command will do:"
    warp_message "* stop containers"
    warp_message "* pull new images"
    warp_message "* remove volume db"
    warp_message "* start containers"

    respuesta_update_db=$( warp_question_ask_default "Do you want to continue? $(warp_message_info [Y/n]) " "Y" )

    if [ "$respuesta_update_db" = "Y" ] || [ "$respuesta_update_db" = "y" ]
    then

        if [ $(warp_check_is_running) = true ]; then
            warp stop --hard
        fi

        #  CHECK IF GITIGNOREFILE CONTAINS FILES WARP TO IGNORE
        [ -f "$HOME/.aws/credentials" ] && cat "$HOME/.aws/credentials" | grep --quiet -w "^[summa-docker]"

        # Exit status 0 means string was found
        # Exit status 1 means string was not found
        if [ $? = 0 ] || [ -f "$HOME/.aws/credentials" ]
        then

            # there are two versions of the AWS client in our infrastructure,
            # this get-login help command only works on the old version, so if it works, run the old one.
            echo "Logging into ECR"
            if aws ecr get-login help &> /dev/null
            then
              $(aws ecr get-login --region us-east-1 --no-include-email --profile summa-docker)
            else
              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $DOCKER_PRIVATE_REGISTRY
            fi

            # check if login Succeeded
            if [ $? = 0 ]
            then
                warp docker pull
                warp volume --rm mysql 2> /dev/null
                warp start
            fi
        fi
    else
        warp_message_warn "* aborting update database"
    fi
}

function mysql_connect_ssh()
{

    if [ "$1" = "-h" ] || [ "$1" = "--help" ]
    then
        mysql_ssh_help
        exit 1
    fi;

    if [ $(warp_check_is_running) = false ]; then
        warp_message_error "The containers are not running"
        warp_message_error "please, first run warp start"

        exit 1;
    fi

    docker-compose -f $DOCKERCOMPOSEFILE exec mysql bash -c "export COLUMNS=`tput cols`; export LINES=`tput lines`; exec bash"
}

function mysql_switch()
{

    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ -z "$1" ]
    then
        mysql_switch_help
        exit 1
    fi;

    if [ $(warp_check_is_running) = true ]; then
        warp_message_error "The containers are running"
        warp_message_error "please, first run warp stop --hard"

        exit 1;
    fi

    MYSQL_VERSION_CURRENT=$(warp_env_read_var MYSQL_VERSION)
    warp_message_info2 "You current MySQL version is: $MYSQL_VERSION_CURRENT"

    if [ $MYSQL_VERSION_CURRENT = $1 ]
    then
        warp_message_info2 "the selected version is the same as the previous one, no changes will be made"
        warp_message_warn "for help run: $(warp_message_bold './warp mysql switch --help')"
    else
        warp_message_warn "This command will destroy MySQL database"
        warp_message "you can create a backup running: $(warp_message_bold './warp mysql dump --help')"
        respuesta_switch_version_db=$( warp_question_ask_default "Do you want to continue? $(warp_message_info [Y/n]) " "Y" )

        if [ "$respuesta_switch_version_db" = "Y" ] || [ "$respuesta_switch_version_db" = "y" ]
        then
            mysql_version=$1
            warp_message_info2 "change version to: $mysql_version"

            MYSQL_VERSION_OLD="MYSQL_VERSION=$MYSQL_VERSION_CURRENT"
            MYSQL_VERSION_NEW="MYSQL_VERSION=$mysql_version"

            cat $ENVIRONMENTVARIABLESFILE | sed -e "s/$MYSQL_VERSION_OLD/$MYSQL_VERSION_NEW/" > "$ENVIRONMENTVARIABLESFILE.warp_tmp"
            mv "$ENVIRONMENTVARIABLESFILE.warp_tmp" $ENVIRONMENTVARIABLESFILE

            cat $ENVIRONMENTVARIABLESFILESAMPLE | sed -e "s/$MYSQL_VERSION_OLD/$MYSQL_VERSION_NEW/" > "$ENVIRONMENTVARIABLESFILESAMPLE.warp_tmp"
            mv "$ENVIRONMENTVARIABLESFILESAMPLE.warp_tmp" $ENVIRONMENTVARIABLESFILESAMPLE

            # delete old files
            rm  -rf $PROJECTPATH/.warp/docker/config/mysql/ 2> /dev/null
            if [ -d $PROJECTPATH/.warp/docker/volumes/mysql ]
            then
                sudo rm -rf $PROJECTPATH/.warp/docker/volumes/mysql/* 2> /dev/null
            fi

            # delete volume database
            warp volume --rm mysql 2> /dev/null

            DOCKER_PRIVATE_REGISTRY=$(warp_env_read_var DOCKER_PRIVATE_REGISTRY)

            if [ ! -z "$DOCKER_PRIVATE_REGISTRY" ] ; then
                NAMESPACE=$(warp_env_read_var NAMESPACE)
                PROJECT=$(warp_env_read_var PROJECT)
                mysql_docker_image="${NAMESPACE}-${PROJECT}-dbs"

                CREATE_MYSQL_IMAGE_FROM="mysql:${mysql_version} ${DOCKER_PRIVATE_REGISTRY}/${mysql_docker_image}:latest"

                # clear custom image
                docker pull "mysql:$mysql_version"
                docker rmi "${DOCKER_PRIVATE_REGISTRY}/${mysql_docker_image}"
                docker tag $CREATE_MYSQL_IMAGE_FROM 2> /dev/null
            fi

            # check files for mysql version
            #warp_mysql_check_files_yaml

            # copy base files
            cp -R $PROJECTPATH/.warp/setup/mysql/config/ $PROJECTPATH/.warp/docker/config/mysql/

            warp_message_warn "* commit new changes"
            warp_message_warn "* at each environment run: $(warp_message_bold './warp reset')"
            warp_message_warn "* after that run: $(warp_message_bold './warp mysql --update')"
        else
            warp_message_warn "* aborting switch database"
        fi
    fi
}

function mysql_dump()
{

    if [ "$1" = "-h" ] || [ "$1" = "--help" ]
    then
        mysql_dump_help
        exit 1
    fi;

    if [ $(warp_check_is_running) = false ]; then
        warp_message_error "The containers are not running"
        warp_message_error "please, first run warp start"

        exit 1;
    fi

    DATABASE_ROOT_PASSWORD=$(warp_env_read_var DATABASE_ROOT_PASSWORD)

    db="$@"

    [ -z "$db" ] && warp_message_error "Database name is required" && exit 1

    MYSQL_DUMP_BIN=$(warp_mysql_dump_bin)
    docker-compose -f $DOCKERCOMPOSEFILE exec mysql bash -c "CMD=\"$MYSQL_DUMP_BIN\"; command -v \"\$CMD\" >/dev/null 2>&1 || CMD=\"mysqldump\"; \"\$CMD\" -uroot -p$DATABASE_ROOT_PASSWORD $db 2> /dev/null"
}

function mysql_import()
{

    if [ "$1" = "-h" ] || [ "$1" = "--help" ]
    then
        mysql_import_help
        exit 1
    fi;

    if [ $(warp_check_is_running) = false ]; then
        warp_message_error "The containers are not running"
        warp_message_error "please, first run warp start"

        exit 1;
    fi

    db=$1

    [ -z "$db" ] && warp_message_error "Database name is required" && exit 1

    DATABASE_ROOT_PASSWORD=$(warp_env_read_var DATABASE_ROOT_PASSWORD)

    MYSQL_CLIENT_BIN=$(warp_mysql_client_bin)
    docker-compose -f $DOCKERCOMPOSEFILE exec -T mysql bash -c "CMD=\"$MYSQL_CLIENT_BIN\"; command -v \"\$CMD\" >/dev/null 2>&1 || CMD=\"mysql\"; \"\$CMD\" -uroot -p$DATABASE_ROOT_PASSWORD $db 2> /dev/null"

}

function mysql_main()
{
    case "$1" in
        dump)
            shift 1
            mysql_dump $*
        ;;

        info)
            mysql_info
        ;;

        import)
            shift 1
            mysql_import $*
        ;;

        connect)
            shift 1
            mysql_connect $*
        ;;

        ssh)
            shift 1
            mysql_connect_ssh $*
        ;;

        switch)
            shift 1
            mysql_switch $*
        ;;

        --update)
            mysql_update_db
        ;;

        -h | --help)
            mysql_help_usage
        ;;

        *)            
            mysql_help_usage
        ;;
    esac
}
