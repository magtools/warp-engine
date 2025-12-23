#!/bin/bash +x

    echo "" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample 
    echo "" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample 
    echo "" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample 
    echo "" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample 

    echo "## CONFIG XDEBUG FOR $php_version ##" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample 
    echo "## CONFIG IONCUBE FOR $php_version ##" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample 
    
     case $php_version in
        '5.6-fpm')
            echo "zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20131226/xdebug.so" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample 
            echo ";zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20131226/iocube.so" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample 
        ;;
        '7.0-fpm')
            echo "zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20151012/xdebug.so" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample 
            echo ";zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20151012/iocube.so" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample 
        ;;
        '7.2-fpm'|'7.2.24-fpm')
            echo "zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20170718/xdebug.so" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample 
            echo ";zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20170718/iocube.so" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample 
        ;;
        '7.3-fpm')
            echo "zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20180731/xdebug.so" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample 
            echo ";zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20180731/iocube.so" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample 
        ;;
        '7.4-fpm'|'7.4.15-fpm')
            echo "zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20190902/xdebug.so" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample 
            echo ";zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20190902/iocube.so" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample 
        ;;
        '8.1.3-fpm'|'8.2.3-fpm'|'8.3-fpm'|'8.4-fpm')
            echo "zend_extension =  /usr/local/lib/php/extensions/no-debug-non-zts-20210902/xdebug.so" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample 
            echo ";zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20210902/iocube.so" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample 
        ;;
        *)
            echo "zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20160303/xdebug.so" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample 
            echo ";zend_extension = /usr/local/lib/php/extensions/no-debug-non-zts-20160303/iocube.so" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample 
        ;;
    esac

    echo "## PHP ###" >> $PROJECTPATH/.warp/docker/config/php/ext-xdebug.ini.sample
    echo "## PHP ###" >> $PROJECTPATH/.warp/docker/config/php/ext-ioncube.ini.sample
