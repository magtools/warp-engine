#!/bin/bash

main () {
    # PROJECTPATH contains the full
    # directory path of the project itself
    PROJECTPATH=$(pwd)

    # SCRIPTNAME contains the name
    # of the current script (e.g. "server")
    SCRIPTNAME="bin/$(basename $0)"

    # Check availability of docker
    hash docker 2>/dev/null || { echo >&2 "warp framework requires \"docker\""; exit 1; }

    # Check availability of docker-compose
    hash docker-compose 2>/dev/null || { echo >&2 "warp framework requires \"docker-compose\""; exit 1; }

    # Check availability of ed
    hash ed 2>/dev/null || { echo >&2 "warp framework requires \"ed command\". On debian install it running \"sudo apt-get install ed\""; exit 1; }

    # Check availability of tr
    hash tr 2>/dev/null || { echo >&2 "warp framework requires \"tr command\". On debian install it running \"sudo apt-get install tr\""; exit 1; }

    [[ $(pwd) =~ [[:space:]]+ ]] && { echo "this folder contains spaces, warp framework requires a folder without spaces"; exit 1; }

    if [ -d $PROJECTPATH/.warp/lib ]; then
        include_warp_framework
    fi;

    if [ -d $PROJECTPATH/.warp/lib ]; then
        # Check minimum versions
        warp_check_docker_version
    fi;

    # check if binary was updated
    warp_check_binary_was_updated

    ## Generate file to check self-update
    # check if the variables are not empty
    if [[ ! -z "$CHECK_UPDATE_FILE" ]] && [[ ! -z "$CHECK_FREQUENCY_DAYS" ]]
    then
        case "$(uname -s)" in
            Darwin)
            # autodetect docker in OSX
            DATE_OSX_LINUX=$(date -v +${CHECK_FREQUENCY_DAYS}d +%Y%m%d)
            ;;
            Linux)
            DATE_OSX_LINUX=$(date -d "+${CHECK_FREQUENCY_DAYS} days" +%Y%m%d)
            ;;
        esac

        if [[ -f "$CHECK_UPDATE_FILE" ]]
        then
            _NEXT_CHECK=$(cat "$CHECK_UPDATE_FILE")
            _TODAY=$(date +%Y%m%d)

            if [[ $_TODAY -ge $_NEXT_CHECK ]] && [[ "$1" != "start" ]]
            then
                warp_check_latest_version
                # update next check
                echo $DATE_OSX_LINUX > "$CHECK_UPDATE_FILE" 2> /dev/null
            fi    
        else
            touch "$CHECK_UPDATE_FILE" 2> /dev/null
            # save next check
            echo $DATE_OSX_LINUX > "$CHECK_UPDATE_FILE" 2> /dev/null
        fi
    fi

    case "$1" in
        init)
        shift 1
        setup_main  $*
        ;;

        mysql)
        shift 1
        mysql_main $*
        ;;

        postgres)
        shift 1
        postgres_main $*
        ;;

        php)
        shift 1
        php_main $*
        ;;

        start)
        start_main $*
        ;;

        fix)
        fix_main $*
        ;;

        xdebug)
        shift 1
        xdebug_main $*
        ;;

        volume)
        shift 1
        volume_main $*
        ;;

        ioncube)
        shift 1
        ioncube_main $*
        ;;

        restart)
        restart_main $*
        ;;

        stop)
        stop_main $*
        ;;

        ps)
        ps_main $*
        ;;

        info)
        shift 1
        warp_info $*
        ;;

        composer)
        composer_main $*
        ;;

        magento)
        magento_main $*
        ;;

        ece-tools|ece-patches)
        magento_main $*
        ;;

        oro)
        oro_main $*
        ;;

        crontab)
        crontab_main $*
        ;;

        npm)
        npm_main $*
        ;;

        grunt)
        grunt_main $*
        ;;

        logs)
        logs_main $*
        ;;

        docker)
        docker_main $*
        ;;

        build)
        build_main $*
        ;;

        elasticsearch)
        shift 1
        elasticsearch_main $*
        ;;

        varnish)
        shift 1
        varnish_main $*
        ;;

        redis)
        shift 1
        redis_main $*
        ;;

        sync)
        shift 1
        sync_main $*
        ;;

        rsync)
        shift 1
        rsync_main $*
        ;;

        rabbit)
        shift 1
        rabbit_main $*
        ;;

        selenium)
        shift 1
        selenium_main $*
        ;;

        mailhog)
        shift 1
        mailhog_main $*
        ;;

        sandbox | sb)
        shift 1
        setup_sandbox_main $*
        ;;

        reset)
        reset_main $*
        ;;

        update)
        shift 1
        warp_update $*
        ;;

        nginx)
        shift
        webserver_main $*
        ;;

        *)
        help
        warp_check_latest_version
        ;;
    esac

    exit 0
}

include_warp_framework() {
    # INCLUDE VARIABLES
    . "$PROJECTPATH/.warp/variables.sh"
    # INCLUDE WARP FRAMEWORK
    . "$PROJECTPATH/.warp/includes.sh"
}

setup_main() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
        setup_help_usage
        exit 0;
    elif [ "$1" = "-n" ] || [ "$1" = "--no-interaction" ] ; then
        if [ ! -d $PROJECTPATH/.warp/setup ]; then
            warp_setup --no-interaction
            exit 0;
        fi;

        init_main init --no-interaction        
        exit 1
    elif [ "$1" = "-mg" ] || [ "$1" = "--mode-gandalf" ] ; then
        if [ ! -d $PROJECTPATH/.warp/setup ]; then
            warp_setup --mode-gandalf $*
            exit 0;
        fi;

        init_main init --mode-gandalf $*
        exit 0;
    else
        if [ ! -d $PROJECTPATH/.warp/setup ]; then
            warp_setup install
            exit 0;
        fi;

        init_main init
    fi
}

setup_sandbox_main() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] && [ ! -d $PROJECTPATH/.warp/setup ] ; then
        setup_help_usage
        exit 0;
    else
        if [ ! -d $PROJECTPATH/.warp/setup ]; then
            warp_setup sandbox
            exit 0;
        fi;

        sandbox_main $*
    fi
}

setup_help_usage() {
    if [ -d $PROJECTPATH/.warp/lib ]; then
        init_help_usage
        exit 0;
    else

        echo "  if you run for the first time, the installation of the framework begins"
        echo "  After the initial installation, a guided menu with options to create services"
        echo "  The following services can be configured:"
        echo "  1) Nginx Web Server"
        echo "  2) PHP service"
        echo "  3) MySQL service"
        echo "  4) Elasticsearch service"
        echo "  5) Redis service for cache, session, fpc"
        echo "  6) Rabbit service"
        echo "  7) Mailhog Server SMTP"
        echo "  8) Varnish service"
        echo "  9) PostgreSQL service"
        echo "  "
        echo "  If the program detects a previous configuration, it shows a shorter menu of options, to configure:"
        echo "  1) Work with one or more projects in parallel"
        echo "  2) Configure service ports"
        echo "  "
        echo "  Please run ./warp init"

        exit 0;
    fi
}

help() {
    if [ -d $PROJECTPATH/.warp/bin ]; then
        warp_banner

        . $PROJECTPATH/.warp/bin/help.sh

        help_main

        for filename in $PROJECTPATH/.warp/bin/*_help.sh; do
            . "$filename"
            $(basename $filename .sh) # execute default function
        done

        help_usage
    else
        warp_message_not_install_yet
        exit 0;
    fi;
}

warp_check_latest_version() {
    if [ ! -f "$PROJECTPATH/.warp/lib/version.sh" ]; then
        return
    fi

    . "$PROJECTPATH/.warp/lib/version.sh"

    if [ -z "$WARP_VERSION" ]; then
        return
    fi

    echo "Version $WARP_VERSION"
}

warp_message_not_install_yet() {
    echo "WARP-ENGINE has not been installed yet."
    echo "Please run ./warp init or ./warp init --help"
}

warp_update() {
    if [ "$1" = "-f" ] || [ "$1" = "--force" ] ; then
        warp_check_latest_version
        exit 0;
    fi;

    if [ ! -d $PROJECTPATH/.warp/lib ]; then
        warp_message_not_install_yet
        exit 0;
    fi;

    if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then
        . "$PROJECTPATH/.warp/bin/update_help.sh"
        update_help_usage
        exit 0;
    fi

    if [ "$1" = "--images" ] ; then
        echo "checking if there are images available to update"
        docker-compose -f $DOCKERCOMPOSEFILE pull
        exit 0;
    fi

    warp_check_latest_version
}

usage() {
    #######################################
    # Print the usage information for the
    # server control script
    # Globals:
    #   SCRIPTNAME
    # Arguments:
    #   None
    # Returns:
    #   None
    #######################################
  echo "Utility for controlling dockerized Web projects\n"
  echo "Usage:\n\n  $SCRIPTNAME <action> [options...] <arguments...>"
  echo ""
}

function warp_info() {
    # IMPORT HELP
    . "$PROJECTPATH/.warp/bin/info_help.sh"

    if [ "$1" = "-h" ] || [ "$1" = "--help" ] ; then  
        info_help_usage
        exit 0;
    fi;    

    if ! warp_check_env_file ; then
        warp_message_error "file not found $(basename $ENVIRONMENTVARIABLESFILE)"
        exit 1;
    fi; 

    if [ "$1" = "--ip" ] ; then
        if [ $(warp_check_is_running) = false ]; then
            warp_message_error "The containers are not running"
            warp_message_error "please, first run warp start"

            exit 1;
        fi

        docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}   {{.Name}}'   $(docker-compose -f  $DOCKERCOMPOSEFILE ps -q) | sed 's/ \// /'
    else
        mysql_main info   
        postgres_main info   
        webserver_main info   
        php_main info   
        elasticsearch_main info   
        varnish_main info   
        redis_main info   
        rabbit_main info   
        mailhog_main info   
    fi;
}

function warp_setup() {
    # Create destination folder
    DESTINATION="."
    #mkdir -p ${DESTINATION}

    OPTION=$1

    # Find __ARCHIVE__ maker, read archive content and decompress it
    ARCHIVE=$(awk '/^__ARCHIVE__/ {print NR + 1; exit 0; }' "${0}")

    tail -n+${ARCHIVE} "${0}" | tar xpJ -C ${DESTINATION}

    if [ "$OPTION" = "sandbox" ]
    then
        if [ -d $PROJECTPATH/.warp/lib ] && [ -d $PROJECTPATH/.warp/bin ] ; then    
            echo "Installing Warp mode Sandbox, wait a few moments"
            sleep 1
            echo "Successful installation!, starting configurations.."
            sleep 1
            # Init Instalation
            include_warp_framework
            sandbox_main init
        fi
    fi

    if [ "$OPTION" = "--no-interaction" ]
    then
        if [ -d $PROJECTPATH/.warp/lib ] && [ -d $PROJECTPATH/.warp/bin ] ; then    
            echo "Installing Warp mode --no-interaction, wait a few moments"
            sleep 1
            echo "Successful installation!, starting without wizard.."
            sleep 1
            # Init Instalation
            include_warp_framework
            init_main init --no-interaction
        fi
    fi

    if [ "$OPTION" = "--mode-gandalf" ]
    then
        if [ -d $PROJECTPATH/.warp/lib ] && [ -d $PROJECTPATH/.warp/bin ] ; then    
            echo "Installing Warp --mode-gandalf, wait a few moments"
            sleep 1
            echo "Successful installation!, starting without wizard.."
            sleep 1
            # Init Instalation
            include_warp_framework
            init_main init --mode-gandalf $*
        fi
    fi

    if [ "$OPTION" = "--force" ]
    then
        echo "Force updating Warp, wait a few moments"
        sleep 1
        echo "Successful update!"
        sleep 1
        # Init Instalation
        include_warp_framework
        # save new version to ENVIRONMENTVARIABLESFILESAMPLE
        warp_env_change_version_sample_file
    fi

    if [ "$OPTION" = "--self-update" ]
    then
        echo "Self update Warp, wait a few moments"
        sleep 1
        echo "Successful update!"
        sleep 1
        # Init Instalation
        include_warp_framework
        # save new version to ENVIRONMENTVARIABLESFILESAMPLE
        warp_env_change_version_sample_file
        # load banner
        warp_banner        
        exit 0;
    fi

    if [ "$OPTION" = "install" ]
    then
        if [ -d $PROJECTPATH/.warp/lib ] && [ -d $PROJECTPATH/.warp/bin ] ; then    
            echo "Installing Warp, wait a few moments"
            sleep 1
            echo "Successful installation!, starting configurations.."
            sleep 1
            # Init Instalation
            include_warp_framework
            init_main init
        fi
    elif [ "$OPTION" = "update" ]
    then
        while : ; do
            respuesta=$( warp_question_ask_default "Are you sure to update Warp Framework? $(warp_message_info [Y/n]) " "Y" )
            if [ "$respuesta" = "Y" ] || [ "$respuesta" = "y" ] || [ "$respuesta" = "N" ] || [ "$respuesta" = "n" ] ; then
                break
            else
                warp_message_warn "Incorrect answer, you must select between two options: $(warp_message_info [Y/n]) "
            fi
        done

        if [ "$respuesta" = "Y" ] || [ "$respuesta" = "y" ]
        then
            echo "Updating Warp, wait a few moments"
            sleep 1
            echo "Successful update!"
            sleep 1
            # Init Instalation
            include_warp_framework
            # save new version to ENVIRONMENTVARIABLESFILESAMPLE
            warp_env_change_version_sample_file
            warp_banner
        fi
    fi
}

function warp_check_binary_was_updated() {
    if [ -f "$ENVIRONMENTVARIABLESFILE" ] && [ -f "$ENVIRONMENTVARIABLESFILESAMPLE" ] && [ -d $PROJECTPATH/.warp/lib ]
    then
        WARP_ENV_VERSION=$(grep "^WARP_VERSION" $ENVIRONMENTVARIABLESFILESAMPLE | cut -d '=' -f2)
        _WARP_ENV_VERSION=$(echo $WARP_ENV_VERSION | tr -d ".")

        . $PROJECTPATH/.warp/lib/version.sh
        _WARP_VERSION=$(echo $WARP_VERSION | tr -d ".")

        if [ ! -z "$WARP_ENV_VERSION" ]
        then
            # .env.sample > version.sh and not equal
            if [ $_WARP_ENV_VERSION -gt $_WARP_VERSION ] && [ ! $_WARP_ENV_VERSION -eq $_WARP_VERSION ]
            then
                # different version binary and current, force update
                warp_message_warn "binary and current version different, force update"
                warp_setup --force

                # save new version to ENVIRONMENTVARIABLESFILESAMPLE
                # warp_env_change_version_sample_file
            fi
        fi
    fi
}

main $*

__ARCHIVE__
