#!/usr/bin/env bash

export PROMOTION_SCRIPT_PATH=${PROMOTION_SCRIPT_PATH:-$( dirname $0 )}
echo "PROMOTION_SCRIPT_PATH: ${PROMOTION_SCRIPT_PATH}"
source ${PROMOTION_SCRIPT_PATH}/syncUpdateUtils.shsource

# this localBuildProperties.shsource file is to ease local builds to override some variables.
# It should not be used for production builds.
source localBuildProperties.shsource 2>/dev/null

function sendPromoteMail ()
{

  SITE_HOST=${SITE_HOST:-download.eclipse.org}

  echo "     Starting sendPromoteMail"
  eclipseStream=$1
  if [[ -z "${eclipseStream}" ]]
  then
    printf "\n\n\t%s\n\n" "ERROR: Must provide eclipseStream as first argument, for this function $(basename $0)"
    return 1;
  fi
  echo "     eclipseStream: ${eclipseStream}"

  buildId=$2
  if [[ -z "${buildId}" ]]
  then
    printf "\n\n\t%s\n\n" "ERROR: Must provide buildId as second argument, for this function $(basename $0)"
    return 1;
  fi
  echo "     buildId: ${buildId}"

  # optional? Or blank?
  BUILD_FAILED=$3


  eclipseStreamMajor=${eclipseStream:0:1}
  buildType=${buildId:0:1}
  echo "     buildType: ${buildType}"

  # ideally, the user executing this mail will have this special file in their home directory,
  # that can specify a custom 'from' variable, but still you must use your "real" ID that is subscribed
  # to the wtp-dev mailing list
  #   set from="\"Your Friendly WTP Builder\" <real-subscribed-id@real.address>"
  # correction ... doesn't work. Seems the subscription system set's the "from" name, so doesn't work when
  # sent to mail list (just other email addresses)
  # especially handy if send from one id (e.g. "david_williams)
  # only good with 'mail', not 'sendmail'
  #export MAILRC=~/.genie.relengmailrc

  # common part of URL and file path
  # varies by build stream
  # examples of end result:
  # http://download.eclipse.org/eclipse/downloads/drops4/N20120415-2015/
  # /home/data/httpd/download.eclipse.org/eclipse/downloads/drops4/N20120415-2015

  comparatorLogRelPath="buildlogs/comparatorlogs/buildtimeComparatorUnanticipated.log.txt"
  fsDocRoot="/home/data/httpd/download.eclipse.org"
  # comparator log is always about 200 or 300 bytes, since it contains some
  # identifying information, such as
  # = = = =
  #    Comparator differences from current build
  #    /shared/eclipse/builds/4N/siteDir/eclipse/downloads/drops4/N20140705-1700
  #       compared to reference repo at
  #     http://download.eclipse.org/eclipse/updates/4.5-I-builds
  # = = = =
  # So we'll set "250 bytes" as minimum which should both ignore all "minimum's",
  # and catch anything of substance.
  # Will adjust as needed.
  comparatorLogMinimumSize=250

  mainPath=$( dlToPath "$eclipseStream" "$buildId")
  echo "     mainPath: $mainPath"
  if [[ "$mainPath" == 1 ]]
  then
    printf "\n\n\t%s\n\n" "ERROR: mainPath could not be computed."
    return 1
  fi

  downloadURL=http://${SITE_HOST}/${mainPath}/${buildId}/
  fsDownloadSitePath=${fsDocRoot}/${mainPath}/${buildId}
  comparatorLogPath=${fsDownloadSitePath}/${comparatorLogRelPath}
  logSize=0
  if [[ -e ${comparatorLogPath} ]]
  then
    logSize=$(stat -c '%s' ${comparatorLogPath} )
    echo -e "DEBUG: comparatorLog found at\n\t${comparatorLogPath}\n\tWith size of $logSize bytes"
  else
    echo -e "DEBUG: comparatorLog was surprisingly not found at:\n\t${comparatorLogPath}"
  fi


  if [[ -n "${BUILD_FAILED}" ]]
  then
    EXTRA_SUBJECT_STRING=" - BUILD FAILED"
  else
    EXTRA_SUBJECT_STRING=""
  fi

  if [[ -n "${POM_UPDATES}" ]]
  then
    EXTRA_SUBJECT_STRING="${EXTRA_SUBJECT_STRING} - POM UPDATES REQUIRED"
  fi

  # 4.3.0 Build: I20120411-2034
   if [[ "${buildType}" == "M" ]]
   then
     SUBJECT="${eclipseStream}a ${buildType}-Build: ${buildId} $EXTRA_SUBJECT_STRING"  
   else
     SUBJECT="${eclipseStream} ${buildType}-Build: ${buildId} $EXTRA_SUBJECT_STRING"
   fi

  setToAndFromAddresses

  # Artificially mark each message for a particular build with unique message-id-like value.
  # Even though technically incorrect for the initial message it seems to work in
  # most situations.
  InReplyTo="<${buildId}@build.eclipse.org/build/eclipse/>"
  Reference="${InReplyTo}"

  # make sure reply to goes back to the list
  # This appears not required for mailing lists?
  #REPLYTO="platform-releng-dev@eclipse.org"

  link=$(linkURL ${downloadURL})
  message1="${message1}<p>Eclipse downloads: <br />\n&nbsp;&nbsp;&nbsp;${link}</p>\n"
  link=$(linkURL ${downloadURL}testResults.php)
  message1="${message1}<p>&nbsp;&nbsp;&nbsp;Build logs and/or test results (eventually): <br />\n&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;${link}</p>\n"

    eclipsebuilder=eclipse.platform.releng.aggregator/production/testScripts

    echo "DEBGUG CBI buildDropDir: ${buildDropDir}"
    echo "DEBUG: CBI builderDropLogsDir: ${builderDropLogsDir}"

  if [[ $logSize -gt  ${comparatorLogMinimumSize} ]]
  then
   link=$(linkURL ${downloadURL}${comparatorLogRelPath})
   echo -e "DEBUG: found logsize greater an minimum. preparing message using ${link}"
   message1="${message1}<p>&nbsp;&nbsp;&nbsp;Check unanticipated comparator messages:  <br />\n&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;${link}<p>\n"
  else
    echo -e "DEBUG: comparator logSize of $logSize was not greater than comparatorLogMinimumSize of ${comparatorLogMinimumSize}"
  fi

  # Do not include repo, if build failed
  if [[ -z "${BUILD_FAILED}" ]]
  then
    # custom message if doing patch build
    if [[ "${buildType}" == "P" || "${buildType}" == "U" ]]
    then 
      link=$(linkURL http://${SITE_HOST}/eclipse/updates/${eclipseStreamMajor}.${eclipseStreamMinor}-${buildType}-builds/${buildId})
      message1="${message1}<p>Specific (simple) site repository: <br />\n&nbsp;&nbsp;&nbsp;${link}</p>\n"
      link=$(linkURL http://${SITE_HOST}/eclipse/updates/${eclipseStreamMajor}.${eclipseStreamMinor}-${buildType}-builds)
      message1="${message1}<p>Remember: The patch must be confirmed before is it added to the composite: <br />\n&nbsp;&nbsp;&nbsp;${link}</p>\n"
    else
      link=$(linkURL http://${SITE_HOST}/eclipse/updates/${eclipseStreamMajor}.${eclipseStreamMinor}-${buildType}-builds)
      message1="${message1}<p>Software site repository: <br />\n&nbsp;&nbsp;&nbsp;${link}</p>\n"
      link=$(linkURL http://${SITE_HOST}/eclipse/updates/${eclipseStreamMajor}.${eclipseStreamMinor}-${buildType}-builds/${buildId})
      message1="${message1}<p>Specific (simple) site repository: <br />\n&nbsp;&nbsp;&nbsp;${link}</p>\n"
    fi
  fi

  # Do not include Equinox, if build failed, or if patch or experimental build
  if [[ -z "${BUILD_FAILED}" && ! "${buildType}" =~ [PYXU]  ]]
  then
    link=$(linkURL http://${SITE_HOST}/equinox/drops/${buildId})
    message1="${message1}<p>Equinox downloads: <br />\n&nbsp;&nbsp;&nbsp;${link}</p>\n"
  fi

  if [[ -n "${POM_UPDATES}" ]]
  then
    message1="${message1}<p>POM Update Required (patches below can be applied on exported email, with <code>git am --scissors --signoff (committerId) &lt; /path/to/patchEmail</code>): <br />\n&nbsp;&nbsp;&nbsp;${downloadURL}pom_updates/</p>\n"
    message1="${message1}<p><pre>\n"
    for file in ${fsDownloadSitePath}/pom_updates/*.diff
    do
      echo "DEBUG: pom update file: $file"
      # rare there would be non-existent file, given the logic that got us here,
      # but we will check just to be sure.
      if [[ -e $file ]]
      then
        # add scissors line ... for each "repo patch"? so extra info is not added to comment
        message1="${message1}\n-- >8 --\n"
        message1="${message1}$(cat $file)"
      fi
    done
    message1="${message1}\n</pre></p>"
  fi

  sendEclipseMail "${TO}" "${FROM}" "${SUBJECT}" "${message1}"

  echo -e "\n\tINFO: mail sent for $eclipseStream $buildType-build $buildId"
  echo -e "\tINFO:\n\t\t${TO}\n\t\t${FROM}\n\t\t${SUBJECT}\n\t\t${message1}\n"
  return 0
}


# start tests function
function startTests()
{
  echo "startTests()"
  eclipseStreamMajor=$1
  buildType=$2
  eclipseStream=$3
  buildId=$4
  EBUILDER_HASH=$5
  if [[ -z "${EBUILDER_HASH}" ]]
  then
    printf "\n\n\t%s\n\n" "ERROR: Must provide builder (or aggregator) hash as fourth argument, for this function $(basename $0)"
    return 1;
  fi

  echo "eclipseStreamMajor: $eclipseStreamMajor"
  echo "buildType: $buildType"
  echo "eclipseStream: $eclipseStream"
  echo "buildId: $buildId"
  echo "EBUILDER_HASH: $EBUILDER_HASH"

  BUILD_ROOT=${BUILD_HOME}/${eclipseStreamMajor}${buildType}
  eclipsebuilder=eclipse.platform.releng.aggregator/production/testScripts
  dlFromPath=$( dlFromPath $eclipseStream $buildId )
  echo "DEBUG CBI dlFromPath: $dlFromPath"
  buildDropDir=${BUILD_ROOT}/siteDir/$dlFromPath/${buildId}
  echo "DEBGUG CBI buildDropDir: $buildDropDir"
  builderDropDir=${buildDropDir}/${eclipsebuilder}
  echo "DEBUG: CBI builderDropDir: ${builderDropDir}"

  # finally, execute ... unless its a patch build
  if [[ "${buildType}" != "P" ]]
  then
    ${builderDropDir}/startTests.sh ${eclipseStream} ${buildId} ${EBUILDER_HASH}
  else
    printf "\n\tNo tests ran for Patch builds.\n"
  fi

  # Since we have already uploaded everything, before invoking tests,
  # if we got an error invoking tests, must copy-up now.
  if [[ -e ${buildDropDir}/TEST_INVOCATION_FAILED.html ]]
  then
    dlSite=$( dropOnDLServer ${eclipseStream} ${buildId} )
    rsync -a ${buildDropDir}/TEST_INVOCATION_FAILED.html  ${dlSite}/${buildId}/
  fi

}

# this function currently sync's local repo on build machine, and adds
# it to composite, on download server.
# NOTE: for patch builds we go ahead and upload, but we do not add to
# composite automatically, until later, when patch is confirmed.
function syncRepoSite ()
{
  eclipseStream=$1
  if [[ -z "${eclipseStream}" ]]
  then
    printf "\n\n\t%s\n\n" "ERROR: Must provide eclipseStream as first argument, for this function $(basename $0)"  >&2
    return 1;
  fi


  buildType=$2
  if [[ -z "${buildType}" ]]
  then
    printf "\n\n\t%s\n\n" "ERROR: Must provide buildType as second argument, for this function $(basename $0)" >&2
    return 1;
  fi

  # contrary to intuition (and previous behavior, bash 3.1) do NOT use quotes around right side of expression.
  if [[ "${eclipseStream}" =~ ^([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)$ ]]
  then
    eclipseStreamMajor=${BASH_REMATCH[1]}
    eclipseStreamMinor=${BASH_REMATCH[2]}
    eclipseStreamService=${BASH_REMATCH[3]}
  else
    echo "eclipseStream, $eclipseStream, must contain major, minor, and service versions, such as 4.2.0" >&2
    return 1
  fi

  fromDir=$(updateSiteOnBuildDir "$eclipseStream" "$buildId" )
  toDir=$(updateSiteOnDL "$eclipseStream" "$buildId" )

  if [[ -n "${fromDir}" && -d "${fromDir}" && -n "${toDir}" && -d "${toDir}" ]]
  then
    # first create XZ compression
    source "${PROMOTION_SCRIPT_PATH}/createXZ.shsource"
    createXZ "${fromDir}"
    RC=$?
    if [[ $RC != 0 ]]
    then
      echo -e "\n\tERROR: createXZ returned non-zero return code: $RC"
      echo -e "\t\tvalue of 'fromDir' was ${fromDir}"
      exit $RC
    fi

    rsync --times --omit-dir-times --recursive "${fromDir}" "${toDir}"
    RC=$?
  else
    RC=9
  fi

  if [[ $RC != 0 ]]
  then
    echo "ERROR: rsync failed. RC: $RC" >&2
    echo "   In syncRepoSite" >&2
    echo "fromDir: $fromDir" >&2
    echo "toDir: $toDir" >&2
    return $RC
  fi


  set -x
  comparatorLogPath="${logsDirectory}/comparatorlogs/buildtimeComparatorUnanticipated.log.txt"
  logSize=$(stat -c '%s' ${comparatorLogPath} )

  if [[ $logSize -lt 250 || "${buildType}" == "Y" ]]
  then
    # update composite!
    # add ${buildId} to {toDir}

    # runAntRunner requires basebuilder to be installed at drop site, so we'll check here if it exists yet,
    # and if not, fetch it.

    dropFromBuildDir=$( dropFromBuildDir "$eclipseStream" "$buildId" )
    EBuilderDir=$dropFromBuildDir/eclipse.platform.releng.aggregator/eclipse.platform.releng.tychoeclipsebuilder

    # assume ant is on the path
    ant -f $EBuilderDir/eclipse/getBaseBuilderAndTools.xml -DWORKSPACE=$dropFromBuildDir

    if [[ "${buildType}" != "P" && "${buildType}" != "U" && "${invisibleBuild}" != "true" ]]
    then
      ${PROMOTION_SCRIPT_PATH}/runAntRunner.sh ${buildId} ${eclipseStream} ${PROMOTION_SCRIPT_PATH}/addToComposite.xml addToComposite -Drepodir=${toDir} -Dcomplocation=${buildId}
      RC=$?
    else
      echo -e "\n\tREMINDER: patch build must be added to composite after confirmation\n"
      RC=0
    fi
  else 
    dlSite=$( dropOnDLServer ${eclipseStream} ${buildId} )
    mkdir -p ${dlSite}/${buildId}
    touch ${dlSite}/${buildId}/buildUnstable
    echo "<p>This build has been marked unstable due to <a href='http://download.eclipse.org/eclipse/downloads/drops4/${buildId}/buildlogs/comparatorlogs/buildtimeComparatorUnanticipated.log.txt'>unanticipated comparator errors</a></p>">> ${dlSite}/${buildId}/buildUnstable
    RC=0
  fi
  set +x
  return $RC
}



# this is the single script to call that "does it all" to promote build
# to update site, drop site, update index page on downlaods, and send mail to list.
# it requires four arguments
#    eclipseStream (e.g. 4.2 or 3.8)
#    buildId       (e.g. N20120415-2015)
#    EBUILDER_HASH (SHA1 HASH or branch of eclipse builder to used

if (( $# < 4 ))
then
  # usage:
  scriptname=$(basename $0)
  printf "\n\t%s\n" "This script, $scriptname requires four arguments, in order: "
  printf "\t\t%s\t%s\n" "eclipseStream" "(e.g. 4.2.2 or 3.8.2) "
  printf "\t\t%s\t%s\n" "buildId" "(e.g. N20120415-2015) "
  printf "\t\t%s\t%s\n" "EBUILDER_HASH" "(SHA1 HASH for eclipe builder used) "
  printf "\t%s\n" "for example,"
  printf "\t%s\n\n" "./$scriptname 4.2 N N20120415-2015 CBI master"
  exit 1
fi

echo "Starting $0"

# = = = = = = = = =  argument checks
eclipseStream=$1
if [[ -z "${eclipseStream}" ]]
then
  printf "\n\n\t%s\n\n" "ERROR: Must provide eclipseStream as first argument, for this function $(basename $0)"
  exit 1
fi
echo "eclipseStream: $eclipseStream"

buildId=$2
if [[ -z "${buildId}" ]]
then
  printf "\n\n\t%s\n\n" "ERROR: Must provide buildId as second argument, for this function $(basename $0)"
  exit 1
fi
echo "buildId: $buildId"

#TODO: assume master for now, if unspecified. But should tighten up to through error as scripts get finished.
EBUILDER_HASH=$3
if [[ -z "${EBUILDER_HASH}" ]]
then
  printf "\n\n\t%s\n\n" "WARNING: Must provide builder (or aggregator) hash as fourth argument, for this function, $0"
  #printf "\n\n\t%s\n\n" "ERROR: Must provide builder (or aggregator) hash as fourth argument, for this function, $0"
  #exit 1;
fi
echo "EBUILDER_HASH: $EBUILDER_HASH"

# we get all build variables here. Currently need it to check if BUILD_FAILED is defined.
# if BUILD FAILED, we still "publish", but dont' update bad repo nor start tests
BUILD_ENV_FILE=$4
source $BUILD_ENV_FILE

eclipseStreamMajor=${eclipseStream:0:1}
buildType=${buildId:0:1}
echo "buildType: $buildType"

# contrary to intuition (and previous behavior, bash 3.1) do NOT use quotes around right side of expression.
if [[ "${eclipseStream}" =~ ^([[:digit:]]+)\.([[:digit:]]+)\.([[:digit:]]+)$ ]]
then
  eclipseStreamMajor=${BASH_REMATCH[1]}
  eclipseStreamMinor=${BASH_REMATCH[2]}
  eclipseStreamService=${BASH_REMATCH[3]}
else
  echo "eclipseStream, $eclipseStream, must contain major, minor, and service versions, such as 4.2.0"
  exit 1
fi

echo "eclipseStream: $eclipseStream"
echo "eclipseStreamMajor: $eclipseStreamMajor"
echo "eclipseStreamMinor: $eclipseStreamMinor"
echo "eclipseStreamService: $eclipseStreamService"
echo "buildType: $buildType"
echo "BUILD_ENV_FILE: $BUILD_ENV_FILE"

# = = = = = = = = =
# compute directory on build machine
dropFromBuildDir=$( dropFromBuildDir "$eclipseStream" "$buildId" )
echo "dropFromBuildDir: $dropFromBuildDir"
if [[ ! -d "${dropFromBuildDir}" ]]
then
  echo "ERROR: the expected dropFromBuildDir (drop directory) did not exist"
  echo "       drop directory: ${dropFromBuildDir}"
  exit 1
fi
export PROMOTION_SCRIPT_PATH=${PROMOTION_SCRIPT_PATH:-$( dirname $0 )}
echo "PROMOTION_SCRIPT_PATH: ${PROMOTION_SCRIPT_PATH}"
${PROMOTION_SCRIPT_PATH}/getEBuilder.sh  "${EBUILDER_HASH}" "${dropFromBuildDir}"

# if build failed, don't promote repo
if [[ -z "$BUILD_FAILED" ]]
then
  syncRepoSite "$eclipseStream" "$buildType"
  rccode=$?
  if [[ $rccode != 0 ]]
  then
    printf "\n\n\t%s\n\n"  "ERROR: something went wrong putting repo on download site. Rest of promoting build halted."
    exit 1
  fi
else
  echo "Repository site not updated since BUILD FAILED"
fi

# We still update drop location, even if failed, just to get the logs up there on downloads
syncDropLocation "$eclipseStream" "$buildId" "${EBUILDER_HASH}"
rccode=$?
if [[ $rccode != 0 ]]
then
  printf "\n\n\t%s\n\n" "ERROR occurred during promotion to download server, so halted promotion and did not send mail."
  exit 1
fi

# if build failed, don't run tests ... they'll fail right away
if [[ -z "$BUILD_FAILED" ]]
then
  # if update to downloads succeeded, start the unit tests on Hudson
  startTests $eclipseStreamMajor $buildType $eclipseStream $buildId ${EBUILDER_HASH}
fi

sendPromoteMail "$eclipseStream" "$buildId" "$BUILD_FAILED"
rccode=$?
if [[ $rccode != 0 ]]
then
  printf "\n\n\t%s\n\n" "ERROR occurred during sending final mail to list"
  exit 1
fi

exit 0

