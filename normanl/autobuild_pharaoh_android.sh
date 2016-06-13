#!/usr/bin/env bash

#set -e
#./autobuild_pharaoh_android.sh slotspharaoh_android release tag/SlotTheme/SlotPharaohv1.3.0
#sourceName=$1
gameName=$1
build_mode=$2
code_path_tag=$3
config_name=$1

# 当前路径
scriptpath=$(cd `dirname $0`;pwd)
# 资源路径
respath=$scriptpath/$gameName
# jp 路径
jq_path=$scriptpath/./jq
# 存放日志文件
log_path=$respath/run_android.log
# 配置文件,存放渠道,描述,目录信息等内容
gameConfig=$scriptpath/${config_name}.json

app_version=1.0.0


# 入参检查
function checkInputPara()
{
	cd "$(dirname "$0")"

	#codePath=`cat ${gameConfig} | $jq_path -r .$gameName.CODE_PATH`
	echo "code_path_tag = "$code_path_tag 
	codePath="../../../../"${code_path_tag}
	echo "codePath = "$codePath
	
	if [ ! -d "$codePath" ]; then  
		echo "code path not found "$codePath
		return 0
	fi

	if [ ! -d $gameName ]; then 
		echo "game dir not found "$gameName
		return 0
	fi
	
	return 1
}

# 设置路径
function setSearchPath()
{
	#追加路径
	#world path, skin path
	echo "=========================add world path begin================================"
	local world=`cat ${gameConfig} | ${jq_path} -r .${gameName}.WD_PATH`
	local skin=`cat ${gameConfig} | ${jq_path} -r .${gameName}.SK_PATH`
	mkdir -pv "$scriptpath/$world"
	mkdir -pv "$scriptpath/$skin"
	world_path=$(cd "$world"; pwd)
	skin_path=$(cd "$skin"; pwd)
	echo "world_path =""${world_path}"
	echo "skin_path =""${skin_path}"
	echo "=========================add world path end================================"

	cd $scriptpath
	cd $codePath

	# 恢复本地代码库
	svn upgrade
	rm -rf $codePath/res
    svn revert -R ./
	svn update

	root_path=`pwd`
	ant_path=~/Documents/Android/adt-bundle-mac-x86_64-20140702/sdk/tools/ant
	echo "root_path = "$root_path
	echo "log_path = "$log_path
	echo "ant_path = "$ant_path
	echo "scriptpath = "$scriptpath
}

# edit 游戏配置,包括(版本,渠道,描述)
function setGameConfig()
{
	local versionFile="${respath}/version_config.txt"
	app_version=`cat $versionFile |sed -n 2p|awk '{print $1}'`
	Luckyo_Casino_Version_Id=`cat $versionFile |sed -n 2p|awk '{print $2}'`
	versionCode=`cat $versionFile |sed -n 2p|awk '{print $3}'`
	app_version_number=`cat $versionFile |sed -n 2p|awk '{print $1}'|awk -F'.' '{print $1$2$3}'`
	#echo ${app_version},${Luckyo_Casino_Version_Id},${versionCode},${app_version_number}
	
	local app_channel=`cat ${gameConfig} | $jq_path -r .${gameName}.APP_CHANNEL`
	echo $app_channel

	echo "=====================edit CommonSetting.h=================="
	local commonSettingPath=$root_path/sources/Constants/CommonSetting.h
	
	sed -i '' "s/#define APP_CHANNEL .*APP_CHANNEL_.*/#define APP_CHANNEL                        ${app_channel}/g" $commonSettingPath
	sed -i '' 's/#define APP_VERSION .*".*"/#define APP_VERSION        "'${app_version}'"/g' $commonSettingPath
	sed -i '' 's/#define APP_VERSION_NUMBER  .* \/\//#define APP_VERSION_NUMBER  '${app_version_number}' \/\//g' $commonSettingPath
	sed -i '' 's/#define Luckyo_Casino_Version_Id .*/#define Luckyo_Casino_Version_Id '${Luckyo_Casino_Version_Id}'/g' $commonSettingPath

	grep '#define APP_CHANNEL' $commonSettingPath
	echo "========================================================"
	grep '#define APP_VERSION' $commonSettingPath
	echo "=========================================================="
	grep '#define Luckyo_Casino_Version_Id' $commonSettingPath
}

function setScriptConfig()
{
	echo "======================set script config==========================="
	local configFile=${root_path}/scripts/Slots/App/SlotsThemeApp.lua
	local appChannelString=`cat ${gameConfig} | ${jq_path} -r .${gameName}.APP_CHANNEL_STRING`

	sed -i '' "s/self.appChannel = self.appChannelMap.*/self.appChannel = self.appChannelMap.${appChannelString}/g" ${configFile}
	sed -i '' "s/self.currentAppName = .*\".*\"/self.appChannel = .*\"${appChannelString}\"/g" ${configFile}
}

# 设置AndroidManifest文件
function setAndroidManifest()
{
	echo "======================edit AndroidManifest.xml===================="
	local manifestFile=$root_path/proj.android/AndroidManifest.xml
	packageName=`cat ${gameConfig} | ${jq_path} -r .${gameName}.PACKAGE_NAME`
	funpageSchemeName=`cat ${gameConfig} | ${jq_path} -r .${gameName}.FUN_PAGE_SCHEME_NAME`
	sed -i '' "s/package=\"casino.saga.slotts.free.casino.games\"/package=\"${packageName}\"/g" $manifestFile
	sed -i '' "s/android:versionCode=\".*\"/android:versionCode=\"${versionCode}\"/g" $manifestFile
	sed -i '' "s/android:versionName=\".*\"/android:versionName=\"${app_version}\"/g" $manifestFile
	#sed -i '' "s/scheme=\"aemobileLuckyo\"/scheme=\"${funpageSchemeName}\"/g" $manifestFile

	grep 'package=' $manifestFile
	grep 'android:versionCode=' $manifestFile
	grep 'android:versionName=' $manifestFile
	grep 'scheme=' $manifestFile
}

# 设置Android相关配置
function setAndroidConfig()
{
	echo "======================edit strings.xml===================="
	local appName=`cat ${gameConfig} | ${jq_path} -r .${gameName}.APP_NAME`
	sed -i '' "s/<string name=\"app_name\">Slots Pharaoh</<string name=\"app_name\">${appName}</g" $root_path/proj.android/res/values/strings.xml

	local facebookId=`cat ${gameConfig} | ${jq_path} -r .${gameName}.FB_CONSUMERKEY`
	sed -i '' "s/<string name=\"facebook_app_id\">.*</<string name=\"facebook_app_id\">${facebookId}</g" $root_path/proj.android/res/values/strings.xml

	grep "app_name" $root_path/proj.android/res/values/strings.xml
	grep "facebook_app_id" $root_path/proj.android/res/values/strings.xml


	echo "=======================replace BASE64_PUBLIC_KEY================"
	local storePublicKey=`cat ${gameConfig} | ${jq_path} -r .${gameName}.STORE_PUBLICKEY`
	sed -i '' "s#static final String PLAY_STORE_BASE64ENCODED_PUBLICKEY = .*#static final String PLAY_STORE_BASE64ENCODED_PUBLICKEY = \"${storePublicKey}\";#g" $root_path/proj.android/src/com/casino/purchase/TNPlayStore.java

	echo "=======================edit *.java=============================="
	replace_package(){
	for file in `ls $1`
	do
	if [ -d $1/${file} ];then
	replace_package $1/${file}
	else
	num=`grep "casino.saga.slotts.free.casino.games.R" $1/${file}|wc -l`
	if [ ${num} -gt 0 ];then
	sed -i '' "s/casino.saga.slotts.free.casino.games.R/${packageName}.R/g" $1/${file}
	grep "import ${packageName}.R"  $1/${file}
	fi
	fi
	done
	}
	replace_package $root_path/proj.android/src
	
	echo "=======================edit GcmPushManager.java=============================="
	sed -i '' "s/casino.saga.slotts.free.casino.games.BuildConfig/${packageName}.BuildConfig/g" $root_path/proj.android/src/com/casino/push/GcmPushManager.java
	sed -i '' "s/casino.saga.slotts.free.casino.games.BuildConfig/${packageName}.BuildConfig/g" $root_path/proj.android/src/org/cocos2dx/lua/AppActivity.java
}

# 设置facebook
function setFaceBookConfig()
{
	# add by wudb
	# modify facebook appid for saga
	echo "=====================edit ShareSDK.xml=================="
	local shareSdkPath=$root_path/proj.android/assets/ShareSDK.xml
	local shareSdkId=`cat ${gameConfig} | ${jq_path} -r .${gameName}.SHARESDK_APPID`
	local consumerKey=`cat ${gameConfig} | ${jq_path} -r .${gameName}.FB_CONSUMERKEY`
	local consumerSecret=`cat ${gameConfig} | ${jq_path} -r .${gameName}.FB_CONSUMERSECRET`
	local clientId=`cat ${gameConfig} | ${jq_path} -r .${gameName}.FB_CLINTID` 
	sed -i '' "s/AppKey = \".*\"/AppKey = \"${shareSdkId}\"/g" ${shareSdkPath}
	sed -i '' "s/ConsumerKey=\"543302069177983\"/ConsumerKey=\"${consumerKey}\"/g" $shareSdkPath
	sed -i '' "s/ConsumerSecret=\"355556731349fb16c809f3990ef6e9ef\"/ConsumerSecret=\"${consumerSecret}\"/g" $shareSdkPath
	sed -i '' "s/ClientId=\"296756313044-afjabtfj466pekj6bnbe2pjiliqmr9ri.apps.googleusercontent.com\"/ClientId=\"${clientId}\"/g" $shareSdkPath
}

# 设置权限
function setPermission()
{
	chmod +x $root_path/../../../shared/cocos2d-x/quick/bin/compile_scripts.sh
	chmod +x $root_path/../../../shared/cocos2d-x/quick/bin/mac/luac
}

# 10.拷贝资源
#function copyResource()
#
#


# android 编译
function buildAndroid()
{
	packageScript=pack_game.py
	
	cd $root_path/game_package
	chmod +x *

	local pack_channel=`cat ${gameConfig} | ${jq_path} -r .${gameName}.PACK_CHANNEL`
	
	if [[ $build_mode == "debug" ]]; then
		python $packageScript android Debug $pack_channel
	elif [[ $build_mode == "release" ]]; then
		python $packageScript android Release $pack_channel
	fi

	cd  $root_path/proj.android
	chmod +x *.sh
	
	echo "=============start run build_native.sh==========="
	if [[ $build_mode == "debug" ]]; then
		echo "=============start run build_native.sh==========="
		./build_native.sh
	elif [[ $build_mode == "release" ]]; then
		echo "=============start run build_native_release.sh==========="
		./build_native_release.sh
	fi

	
	if [ -f libs/armeabi/libcocos2dlua.so ]; then 
		echo "build success"
	else
		echo "build failed"
		exit
	fi
}

# 打包Android资源
function antAndroid()
{
	cd  $root_path/proj.android
	android update project --name AppActivity --target android-20 -p ./
	sleep 2
	cd facebook/
	android update lib-project --target android-20 -p ./
	sleep 2
	cd $root_path/../../../shared/cocos2d-x//cocos/platform/android/java
	android update lib-project --target android-20 -p ./
	sleep 2
	cd  $root_path/proj.android
	android update project --name AppActivity --target android-20 -p ./ --subprojects
	sleep 2

	if [ `grep "key.store" $root_path/proj.android/ant.properties |wc -l` -eq 1 ];then
		local certification=`cat ${gameConfig} | ${jq_path} -r .${gameName}.CERTIFICATION`
		local cert_alias=`cat ${gameConfig} | ${jq_path} -r .${gameName}.CERTIFICATION_ALIAS`
		echo "key.store=${respath}/${certification}">>ant.properties
		echo 'key.store.password=SHEN123!@#AB'>>ant.properties
		echo "key.alias=${cert_alias}">>ant.properties
		echo 'key.alias.password=SHEN123!@#AB'>>ant.properties

		grep 'key.store' ant.properties
	fi

	rm -f bin/*.apk

	cd  $root_path/proj.android

	echo "========== ant apk start ==============="

	ant clean 

	# 替换jdk 为1.7版本编译
	sed -i '' "/source/s/1.5/1.7/g" $ant_path/build.xml
	sed -i '' "/target/s/1.5/1.7/g" $ant_path/build.xml

	ant release 
	# 替换jdk 为1.5版本编译
	sed -i '' "/source/s/1.7/1.5/g" $ant_path/build.xml
	sed -i '' "/target/s/1.7/1.5/g" $ant_path/build.xml
	ant release 

	# create dir
	if [[ $build_mode == "debug"  ]]; then
			copy_apk_path=/build/${gameName}/${code_path_tag}/debug/
		
	elif [[ $build_mode == "release"  ]]; then
		copy_apk_path=/build/${gameName}/${code_path_tag}/release/
	fi
	
	mkdir -pv ${copy_apk_path}

    echo "========== ant apk success, copy apk to build ==============="
    echo ${copy_apk_path}
	if [[ $build_mode == "debug"  ]]; then
		cp bin/AppActivity-release.apk ${copy_apk_path}/${gameName}_${app_version}_D_`date +%m%d`_`date +%H%M`.apk	
	elif [[ $build_mode == "release"  ]]; then
		cp bin/AppActivity-release.apk ${copy_apk_path}/${gameName}_${app_version}_R_`date +%m%d`_`date +%H%M`.apk
	fi
	
	
		#设置读的权限
	chmod -R 777 /build/${gameName}
	echo "========== copy success ==============="
}

# 打android 支付测试包
function antAndroidPayTest()
{
	echo "=================generate apk for testing payment ======================="
	versionCodeNext=`expr ${versionCode} - 1`
	echo "versionCodeNext = "${versionCodeNext}
	echo "======================edit AndroidManifest.xml===================="
	sed -i '' "s/android:versionCode=\".*\"/android:versionCode=\"${versionCodeNext}\"/g" $root_path/proj.android/AndroidManifest.xml

	grep 'android:versionCode=' $root_path/proj.android/AndroidManifest.xml

	cd  $root_path/proj.android

	rm -f bin/*.apk

	sed -i '' "/source/s/1.7/1.5/g" $ant_path/build.xml
	ant release

	echo "========== ant apk success, copy apk to build ==============="
    echo ${copy_apk_path}
	if [[ $build_mode == "debug"  ]]; then
		cp bin/AppActivity-release.apk ${copy_apk_path}/${gameName}_${app_version}_PAY${versionCodeNext}_D_`date +%m%d`_`date +%H%M`.apk	
	elif [[ $build_mode == "release"  ]]; then
		cp bin/AppActivity-release.apk ${copy_apk_path}/${gameName}_${app_version}_PAY${versionCodeNext}_R_`date +%m%d`_`date +%H%M`.apk	
	fi
	
	#设置读的权限
	chmod -R 777 /build/${gameName}
	echo "========== copy android pay success ==============="
}

# 拷贝图片
function setGameResource()
{
	echo "========================replace icon======================"
	rm -f $root_path/proj.android/res/drawable/icon.png
	cp $respath/icon/icon_48.png $root_path/proj.android/res/drawable/icon.png

	rm -f $root_path/proj.android/res/drawable-hdpi/icon.png
	cp $respath/icon/icon_72.png $root_path/proj.android/res/drawable-hdpi/icon.png

	rm -f $root_path/proj.android/res/drawable-ldpi/icon.png
	cp $respath/icon/icon_48.png $root_path/proj.android/res/drawable-ldpi/icon.png

	rm -f $root_path/proj.android/res/drawable-mdpi/icon.png
	cp $respath/icon/icon_48.png $root_path/proj.android/res/drawable-mdpi/icon.png

	rm -f $root_path/proj.android/res/drawable-xhdpi/icon.png
	cp $respath/icon/icon_96.png $root_path/proj.android/res/drawable-xhdpi/icon.png

	rm -f $root_path/proj.android/res/drawable-xxhdpi/icon.png
	cp $respath/icon/icon_144.png $root_path/proj.android/res/drawable-xxhdpi/icon.png

	rm -f $root_path/proj.android/res/drawable-xxxhdpi/icon.png
	cp $respath/icon/icon_192.png $root_path/proj.android/res/drawable-xxxhdpi/icon.png


	echo "==================replace Music and PNG ============================"
	#loading
	rm -f $root_path/res/SlotsTheme/LoginWidget/loading_background.png
	cp $respath/LoginWidget/loading_background.png $root_path/res/SlotsTheme/LoginWidget/loading_background.png

	#logo
	rm -f $root_path/res/SlotsTheme/Logo/slotsThemeLogo.png
	cp $respath/Logo/slotsThemeLogo.png $root_path/res/SlotsTheme/Logo/slotsThemeLogo.png

	#Music
	rm -f $root_path/res/SlotsTheme/Music/slotThemeMusic.mp3
	cp $respath/Music/slotThemeMusic.mp3 $root_path/res/SlotsTheme/Music/slotThemeMusic.mp3
}

function copyWorldResource()
{
	local world_path_res=`cat ${gameConfig} | ${jq_path} -r .${gameName}.WD_PATH_RES`
	local skin_path_res=`cat ${gameConfig} | ${jq_path} -r .${gameName}.SK_PATH_RES`

	echo "==================replace First world and first skin ============================"
	rm -r $root_path/res/SlotsTheme/SlotPharaoh
	mkdir -pv $root_path/res/SlotsTheme/${world_path_res}
	chmod -R 777 $root_path/res/SlotsTheme/${world_path_res}
	cp -r ${world_path} $root_path/res/SlotsTheme/${world_path_res}/../

	echo "skin_path2 = "${skin_path}
	rm -r $root_path/res/Slots/casinoegypt
	mkdir -pv $root_path/res/${skin_path_res}
	chmod -R 777 $root_path/res/${skin_path_res}
	cp -r "${skin_path}" $root_path/res/${skin_path_res}/../
}

function main()
{
	# 1.入参检查
	if checkInputPara; then
		echo "para error"]
		return
	fi

	# 2.设置路劲参数
	setSearchPath

	# 4.设置Commsetting.h等 C++配置
	setGameConfig
	setScriptConfig

    # icon, 替换
	setGameResource
	copyWorldResource
	
	# 6.设置权限
	setPermission
	
	# 7.android 编译
	buildAndroid
	
	# 8.设置Android相关配置
	setAndroidManifest
	setAndroidConfig

	# 9.设置facebook配置
	setFaceBookConfig

	# 10.拷贝资源
	#copyResource
	
	# 11.打包
	antAndroid
	
	# 11.打android 支付测试包
	antAndroidPayTest
}

main


