function before_integrate()
{
    if [ "$PKG_TYPE" = "C" ];then
        MY_PKG_PREFIX="ClientService"
        LOCAL_PKG_PATH=$WORKSPACE/package/$FTPDIR/service/$MY_PKG_PREFIX/$APP_PLATFORM
    elif [ "$PKG_TYPE" = "S" ];then
        MY_PKG_PREFIX="AnyBackupServer"
        LOCAL_PKG_PATH=$WORKSPACE/package/$FTPDIR/package/$MY_PKG_PREFIX/$APP_PLATFORM
    elif [ "$PKG_TYPE" = "D" ];then
        MY_PKG_PREFIX="DedupeService"
        LOCAL_PKG_PATH=$WORKSPACE/package/$FTPDIR/service/$MY_PKG_PREFIX/$APP_PLATFORM
    elif [ "$PKG_TYPE" = "O" ];then
        MY_PKG_PREFIX="EOSSService"
        LOCAL_PKG_PATH=$WORKSPACE/package/$FTPDIR/service/$MY_PKG_PREFIX/$APP_PLATFORM
    elif [ "$PKG_TYPE" = "T" ];then
        MY_PKG_PREFIX="ETSSService"
        LOCAL_PKG_PATH=$WORKSPACE/package/$FTPDIR/service/$MY_PKG_PREFIX/$APP_PLATFORM
    elif [ "$PKG_TYPE" = "P" ];then
        MY_PKG_PREFIX="ProxyService"
        LOCAL_PKG_PATH=$WORKSPACE/package/$FTPDIR/service/$MY_PKG_PREFIX/$APP_PLATFORM
	elif [ "$PKG_TYPE" = "A" ];then
        MY_PKG_PREFIX="AnyBackupCDMServer"
        LOCAL_PKG_PATH=$WORKSPACE/package/$FTPDIR/package/$MY_PKG_PREFIX/$APP_PLATFORM
	elif [ "$PKG_TYPE" = "B" ];then
        MY_PKG_PREFIX="CDMClientService"
        LOCAL_PKG_PATH=$WORKSPACE/package/$FTPDIR/service/$MY_PKG_PREFIX/$APP_PLATFORM
    fi
    mkdir -p $LOCAL_PKG_PATH
    MY_PKG_TIME=`date +%Y%m%d`
    MY_PKG_NAME=${MY_PKG_PREFIX}-$APP_PLATFORM-$MY_PKG_Ver-$MY_PKG_TIME-$MY_PKG_Ver_Status-$LANG-$BUILD_NUMBER
    MY_PKG_DIR_NAME=${MY_PKG_PREFIX}-${APP_PLATFORM}-`date +%Y%m%d%H%M%S`-${BUILD_NUMBER}
    mkdir -p $WORKSPACE/$MY_PKG_NAME/$MY_PKG_DIR_NAME/$MY_PKG_PREFIX
    cd $WORKSPACE/$MY_PKG_NAME/$MY_PKG_DIR_NAME/$MY_PKG_PREFIX
    echo "Package Name=$MY_PKG_NAME">VersionDetails
}

function integrate()
{
    cat ${WORKSPACE}/envbase.csv | while read line || [[ -n ${line} ]]
    do
        if [ `echo $line |cut -d "," -f 1 | grep -c "$PKG_TYPE"` -ge 1 ];then
            MODULE_NAME=`echo $line |cut -d "," -f 2`
            if [[ $MODULE_NAME == "ProxyService" && $APP_PLATFORM != "Windows_All_x64" ]];then
                continue
            fi
            if [[ $MODULE_NAME == "keepalived" && $APP_PLATFORM != "Linux_el7_x64" ]];then
                continue
            fi
            FTP_PATH=$FTPROOT/module
            if [[ $PKG_TYPE == "S" && $MODULE_NAME != "www" && $MODULE_NAME != "server_setup" ]];then
                FTP_PATH=$FTPROOT/service
            fi
            if [[ $PKG_TYPE == "A" && $MODULE_NAME != "www" && $MODULE_NAME != "server_setup" ]];then
                FTP_PATH=$FTPROOT/service
            fi

            if [ $APP_PLATFORM == "Windows_All_x64" ];then
                unzip $FTP_PATH/$MODULE_NAME/$APP_PLATFORM/latest.zip | cut -d ':' -f 2 | cut -d '/' -f 1 | sort -u | tee -a VersionDetails
            else
                tar zxvf $FTP_PATH/$MODULE_NAME/$APP_PLATFORM/latest.tar.gz --strip-components=1 |  cut -d '/' -f 1 | sort -u | tee -a VersionDetails
            fi
        fi
    done

    if [ $APP_PLATFORM == "Windows_All_x64" ];then
        rm -rf ../temp;mkdir ../temp;mv VersionDetails ../temp;cp -r */* ../temp;rm -rf *;mv ../temp/* ./;rm -rf ../temp
        COMPRESS_CMD="zip -r"
        PKG_SUFFIX=zip
        if [[ "$PKG_TYPE" != "S" && "$PKG_TYPE" != "A" ]];then
            mkdir debuginfo
            find . -name "*.pdb" | xargs -i mv {} debuginfo
        fi
    else
        COMPRESS_CMD="tar czf"
        PKG_SUFFIX=tar.gz
    fi
    cd $WORKSPACE/$MY_PKG_NAME
    if [[ "$PKG_TYPE" != "S" && "$PKG_TYPE" != "A" ]];then
        $COMPRESS_CMD $LOCAL_PKG_PATH/$MY_PKG_NAME-debuginfo.$PKG_SUFFIX ${MY_PKG_DIR_NAME}/$MY_PKG_PREFIX/debuginfo
        rm -rf ${MY_PKG_DIR_NAME}/$MY_PKG_PREFIX/debuginfo
    fi

    if [ -f ${MY_PKG_DIR_NAME}/$MY_PKG_PREFIX/install.sh ]; then
        chmod +x ${MY_PKG_DIR_NAME}/$MY_PKG_PREFIX/*.sh
    fi

    if [[ "$PKG_TYPE" == "S" || "$PKG_TYPE" == "A" ]];then
        mv ${MY_PKG_DIR_NAME}/${MY_PKG_PREFIX} $MY_PKG_PREFIX
        mv ${MY_PKG_PREFIX}/www ${MY_PKG_PREFIX}/WebService/
        $COMPRESS_CMD $LOCAL_PKG_PATH/$MY_PKG_NAME.$PKG_SUFFIX $MY_PKG_PREFIX
    else
        $COMPRESS_CMD $LOCAL_PKG_PATH/$MY_PKG_NAME.$PKG_SUFFIX $MY_PKG_DIR_NAME
    fi
    ClientName=AnyBackupClient
    if [ "$PKG_TYPE" == "B" ];then
        ClientName=AnyBackupCDMClient
    fi
    if [[ "$PKG_TYPE" == "C" || "$PKG_TYPE" == "B" ]];then
        mv ${MY_PKG_DIR_NAME}/${MY_PKG_PREFIX} $ClientName
        if [ -f $ClientName/install.sh ];then
            chmod +x $ClientName/*install.sh
        fi
        mkdir -p $WORKSPACE/package/$FTPDIR/package/$ClientName/$APP_PLATFORM
        C_PKG_NAME=${MY_PKG_NAME/$MY_PKG_PREFIX/$ClientName}
        $COMPRESS_CMD $WORKSPACE/package/$FTPDIR/package/$ClientName/$APP_PLATFORM/$C_PKG_NAME.$PKG_SUFFIX $ClientName
        cd $WORKSPACE/package/$FTPDIR/package/$ClientName/$APP_PLATFORM
        ln -sf $C_PKG_NAME.$PKG_SUFFIX latest.$PKG_SUFFIX
    fi

    cd $LOCAL_PKG_PATH
    ln -sf $MY_PKG_NAME.$PKG_SUFFIX latest.$PKG_SUFFIX
}

#
#main
#
PKG_TYPE=$1
LANG='zh_CN'
FTPDIR='AB7.0'
MY_PKG_Ver='7.0.0'
MY_PKG_Ver_Status='release'
FTPROOT="/mnt/jenkinsftp/ci-jobs/$FTPDIR"


cat ${WORKSPACE}/platform_list.txt | while read line || [[ -n ${line} ]]
do
    if [[ ${line} == ${JOB_NAME}* ]]; then
        platform_list=${line#*:}
        findMark="`echo ${platform_list}|grep ','`"
        if [ -z "${findMark}" ]; then
            APP_PLATFORM=${platform_list}
            before_integrate
            integrate
        else
            i=1
            while(true)
            do
                APP_PLATFORM="`echo ${platform_list}|cut -d ',' -f $i`"
                if [ -z "${APP_PLATFORM}" ]; then
                    break
                fi
                before_integrate
                integrate
                ((i++))
            done
        fi
        break
    fi
done
