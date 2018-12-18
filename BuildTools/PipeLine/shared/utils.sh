# duplicati root is relative to the stage dirs
DUPLICATI_ROOT="$( cd "$(dirname "$0")" ; pwd -P )/../../../"
BUILD_CACHE="${DUPLICATI_ROOT}/../.duplicati_build_cache"
TEST_CACHE="${DUPLICATI_ROOT}/../.duplicati_test_cache"
ZIP_CACHE="${DUPLICATI_ROOT}/../.duplicati_zip_cache"
INSTALLER_CACHE="${DUPLICATI_ROOT}/../.duplicati_installer_cache"
DEPLOY_CACHE="${DUPLICATI_ROOT}/../.duplicati_deploy_cache"

declare -a FORWARD_OPTS

function quit_on_error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  if [[ -n "$message" ]] ; then
    echo "Error in $0 line ${parent_lineno}: ${message}; exiting with status ${code}"
  else
    echo "Error in $0 line ${parent_lineno}; exiting with status ${code}"
  fi
  exit "${code}"
}

set -eE
trap 'quit_on_error $LINENO' ERR

function travis_mark_begin () {
    echo "travis_fold:start:$1"
    echo "+ START $1"
}

function travis_mark_end () {
    echo "travis_fold:end:$1"
    echo "+ DONE $1"
}

function get_keyfile_password () {
	if [ "z${KEYFILE_PASSWORD}" == "z" ]; then
		echo -n "Enter keyfile password: "
		read -s KEYFILE_PASSWORD
		echo

        if [ "z${KEYFILE_PASSWORD}" == "z" ]; then
            echo "No password entered, quitting"
            exit 0
        fi

        export KEYFILE_PASSWORD
	fi
}

function set_gpg_data () {
	if [ $SIGNED != true ]; then
		return
	fi

	get_keyfile_password

	GPGDATA=$(mono "BuildTools/AutoUpdateBuilder/bin/Debug/SharpAESCrypt.exe" d "${KEYFILE_PASSWORD}" "${GPG_KEYFILE}")
	if [ ! $? -eq 0 ]; then
		echo "Decrypting GPG keyfile failed"
		exit 1
	fi
	GPGID=$(echo "${GPGDATA}" | head -n 1)
	GPGKEY=$(echo "${GPGDATA}" | head -n 2 | tail -n 1)
}

function sign_with_authenticode () {
	if [ ! -f "${AUTHENTICODE_PFXFILE}" ] || [ ! -f "${AUTHENTICODE_PASSWORD}" ]; then
		echo "Skipped authenticode signing as files are missing"
		return
	fi

	echo "Performing authenticode signing of installers"

    get_keyfile_password

	if [ "z${PFX_PASS}" == "z" ]; then
        PFX_PASS=$("${MONO}" "${DUPLICATI_ROOT}/BuildTools/AutoUpdateBuilder/bin/Debug/SharpAESCrypt.exe" d "${KEYFILE_PASSWORD}" "${AUTHENTICODE_PASSWORD}")

        DECRYPT_STATUS=$?
        if [ "${DECRYPT_STATUS}" -ne 0 ]; then
            echo "Failed to decrypt, SharpAESCrypt gave status ${DECRYPT_STATUS}, exiting"
            exit 4
        fi

        if [ "x${PFX_PASS}" == "x" ]; then
            echo "Failed to decrypt, SharpAESCrypt gave empty password, exiting"
            exit 4
        fi
    fi

	NEST=""
	for hashalg in sha1 sha256; do
		SIGN_MSG=$(osslsigncode sign -pkcs12 "${AUTHENTICODE_PFXFILE}" -pass "${PFX_PASS}" -n "Duplicati" -i "http://www.duplicati.com" -h "${hashalg}" ${NEST} -t "http://timestamp.verisign.com/scripts/timstamp.dll" -in "$1" -out tmpfile)
		if [ "${SIGN_MSG}" != "Succeeded" ]; then echo "${SIGN_MSG}"; fi
		mv tmpfile "${ZIPFILE}"
		NEST="-nest"
	done
}

install_oem_files () {
    SOURCE_DIR=$1
    TARGET_DIR=$2
    for n in "../oem" "../../oem" "../../../oem"
    do
        if [ -d "${SOURCE_DIR}/$n" ]; then
            echo "Installing OEM files"
            cp -R "${SOURCE_DIR}/$n" "${TARGET_DIR}/webroot/"
        fi
    done

    for n in "oem-app-name.txt" "oem-update-url.txt" "oem-update-key.txt" "oem-update-readme.txt" "oem-update-installid.txt"
    do
        for p in "../$n" "../../$n" "../../../$n"
        do
            if [ -f "${SOURCE_DIR}/$p" ]; then
                echo "Installing OEM override file"
                cp "${SOURCE_DIR}/$p" "${TARGET_DIR}"
            fi
        done
    done
}

function pull_docker_image () {
  travis_mark_begin "PULL MINIMAL DOCKER IMAGE"
  docker pull $DOCKER_IMAGE
  travis_mark_end "PULL MINIMAL DOCKER IMAGE"
}

function run_with_docker () {
  if [ -z ${TARGET_CACHE} ]; then
    echo "no target cache specified"
    exit 1
  fi

  docker run -e WORKING_DIR="$TARGET_CACHE" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${TARGET_CACHE}:/duplicati" \
  -v "${SOURCE_CACHE}:/.cache" \
  --privileged --rm $DOCKER_IMAGE "/.cache/BuildTools/PipeLine/shared/runner.sh" "${FORWARD_OPTS[@]}"
}

function parse_options () {
  QUIET=false
  FORWARD_OPTS=""
  CACHE_MONO=false
  RELEASE_VERSION="2.0.4.$(cat "$DUPLICATI_ROOT"/Updates/build_version.txt)"
  RELEASE_TYPE="canary"
  SIGNED=false

  while true ; do
      case "$1" in
      --cache_mono)
        CACHE_MONO=true
        ;;
      --unsigned)
        SIGNED=false
        ;;
      --version)
        RELEASE_VERSION="$2"
        shift
        ;;
      --releasetype)
        RELEASE_TYPE="$2"
        shift
        ;;
      --dockercommand)
        DOCKER_COMMAND="$2"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
      --dockerpackages)
        DOCKER_PACKAGES="$2"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
      --dockerimage)
        DOCKER_IMAGE="$2"
        shift
        ;;
      --installers)
        INSTALLERS="$2"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
    	--quiet)
        IF_QUIET_SUPPRESS_OUTPUT=" > /dev/null"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
    		;;
      --testdata)
        TEST_DATA=$2
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
      --sourcecache)
        SOURCE_CACHE="$2"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
      --targetcache)
        TARGET_CACHE="$2"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
      --gittag)
        GIT_TAG=$2
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
      --testcategories)
        TEST_CATEGORIES=$2
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
      --awskeyid)
        AWS_ACCESS_KEY_ID="$2"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
      --awssecret)
        AWS_SECRET_ACCESS_KEY="$2"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
      --awsbucket)
        AWS_BUCKET_URI="$2"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$1"
        FORWARD_OPTS[${#FORWARD_OPTS[@]}]="$2"
        shift
        ;;
      # TODO: need better forwarding logic
      --* | -* )
        echo "unknown option $1, please use --help."
        exit 1
        ;;
      * )
        break
        ;;
      esac
      shift
  done

  RELEASE_CHANGELOG_FILE="${DUPLICATI_ROOT}/changelog.txt"
  RELEASE_CHANGELOG_NEWS_FILE="${DUPLICATI_ROOT}/changelog-news.txt" # never in repo due to .gitignore
  RELEASE_TIMESTAMP=$(date +%Y-%m-%d)
  RELEASE_NAME="${RELEASE_VERSION}_${RELEASE_TYPE}_${RELEASE_TIMESTAMP}"
  RELEASE_FILE_NAME="duplicati-${RELEASE_NAME}"
  RELEASE_NAME_SIMPLE="duplicati-${RELEASE_VERSION}"
	UPDATE_SOURCE="${DUPLICATI_ROOT}/Updates/build/${RELEASE_TYPE}_source-${RELEASE_VERSION}"
  UPDATE_TARGET="${DUPLICATI_ROOT}/Updates/build/${RELEASE_TYPE}_target-${RELEASE_VERSION}"
  ZIPFILE="${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip"
#  BUILDTAG_RAW=$(echo "${RELEASE_FILE_NAME}" | cut -d "." -f 1-4 | cut -d "-" -f 2-4)
  BUILDTAG="${RELEASE_TYPE}_${RELEASE_TIMESTAMP}_${GIT_TAG}"
  BUILDTAG=${BUILDTAG//-}
  AUTHENTICODE_PFXFILE="${HOME}/.config/signkeys/Duplicati/authenticode.pfx"
  AUTHENTICODE_PASSWORD="${HOME}/.config/signkeys/Duplicati/authenticode.key"
  GPG_KEYFILE="${HOME}/.config/signkeys/Duplicati/updater-gpgkey.key"
  GPG=/usr/local/bin/gpg2
  # Newer GPG needs this to allow input from a non-terminal
  export GPG_TTY=$(tty)
}

function run () {
  parse_options "$@"
  pull_docker_image
  run_with_docker
}