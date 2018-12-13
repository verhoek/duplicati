#!/bin/bash
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/utils.sh"

function build_installer () {
    DIRNAME=$(echo "${RELEASE_FILE_NAME}" | cut -d "_" -f 1)
    installer_dir="${DUPLICATI_ROOT}/BuildTools/Installer/Synology"
    DATE_STAMP=$(LANG=C date -R)
    BASE_FILE_NAME="${RELEASE_FILE_NAME%.*}"
    TMPDIRNAME="${installer_dir}/${BASE_FILE_NAME}-extract"

    TIMESERVER="http://timestamp.synology.com/timestamp.php"

    unzip -q -d "${installer_dir}/${DIRNAME}" "$ZIPFILE"

    install_oem_files "${installer_dir}" "${DIRNAME}"

    # Remove items unused on the Synology platform
    rm -rf ${installer_dir}/${DIRNAME}/win-tools
    rm -rf ${installer_dir}/${DIRNAME}/SQLite/win64
    rm -rf ${installer_dir}/${DIRNAME}/SQLite/win32
    rm -rf ${installer_dir}/${DIRNAME}/MonoMac.dll
    rm -rf ${installer_dir}/${DIRNAME}/alphavss
    rm -rf ${installer_dir}/${DIRNAME}/OSX\ Icons
    rm -rf ${installer_dir}/${DIRNAME}/OSXTrayHost
    rm -rf ${installer_dir}/${DIRNAME}/AlphaFS.dll
    rm -rf ${installer_dir}/${DIRNAME}/AlphaVSS.Common.dll
    rm -rf ${installer_dir}/${DIRNAME}/licenses/alphavss
    rm -rf ${installer_dir}/${DIRNAME}/licenses/MonoMac
    rm -rf ${installer_dir}/${DIRNAME}/licenses/gpg

    # Install extra items for Synology
    cp -R ${installer_dir}/web-extra/* ${installer_dir}/${DIRNAME}/webroot/
    cp ${installer_dir}/dsm.duplicati.conf ${installer_dir}/${DIRNAME}

    DIRSIZE_KB=$(BLOCKSIZE=1024 du -s | cut -d '.' -f 1)
    let "DIRSIZE=DIRSIZE_KB*1024"

    tar cf ${installer_dir}/package.tgz -C "${installer_dir}/${DIRNAME}" "${installer_dir}/${DIRNAME}"/*

    ICON_72=$(openssl base64 -A -in "${installer_dir}"/PACKAGE_ICON.PNG)
    ICON_256=$(openssl base64 -A -in "${installer_dir}"/PACKAGE_ICON_256.PNG)

    echo "version=\"${RELEASE_VERSION}\"" >> "${installer_dir}/INFO"
    MD5=$(md5sum "${installer_dir}/package.tgz" | awk -F ' ' '{print $NF}')
    echo "checksum=\"${MD5}\"" >> "${installer_dir}/INFO"
    echo "extractsize=\"${DIRSIZE_KB}\"" >> "${installer_dir}/INFO"
    echo "package_icon=\"${ICON_72}\"" >> "${installer_dir}/INFO"
    echo "package_icon_256=\"${ICON_256}\"" >> "${installer_dir}/INFO"

    chmod +x ${installer_dir}/scripts/*

    tar cf "${installer_dir}/${BASE_FILE_NAME}.spk" -C ${installer_dir} "${installer_dir}/"INFO "${installer_dir}/"LICENSE "${installer_dir}/"*.PNG \
    "${installer_dir}/"package.tgz "${installer_dir}/"scripts
    # TODO: These folders are not present in git: "${SCRIPT_DIR}/"conf "${SCRIPT_DIR}/"WIZARD_UIFILES . Remove?


    set_gpg_data

    if [ "z${GPGID}" != "z" ]; then
        # Now codesign the spk file
        mkdir "${TMPDIRNAME}"
        tar xf "${BASE_FILE_NAME}.spk" -C "${TMPDIRNAME}"
        # Sort on macOS does not have -V / --version-sort
        # https://stackoverflow.com/questions/4493205/unix-sort-of-version-numbers
        SORT_OPTIONS="-t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n"

        cat $(find ${TMPDIRNAME} -type f | sort ${SORT_OPTIONS}) > "${BASE_FILE_NAME}.spk.tmp"

        gpg2 --ignore-time-conflict --ignore-valid-from --yes --batch --armor --detach-sign --default-key="${GPGID}" --output "${BASE_FILE_NAME}.signature" "${BASE_FILE_NAME}.spk.tmp"
        rm "${BASE_FILE_NAME}.spk.tmp"

        curl --silent --form "file=@${BASE_FILE_NAME}.signature" "${TIMESERVER}" > "${TMPDIRNAME}/syno_signature.asc"
        rm "${BASE_FILE_NAME}.signature"

        rm "${BASE_FILE_NAME}.spk"
        tar cf "${BASE_FILE_NAME}.spk" -C "${TMPDIRNAME}" $(ls -1 ${TMPDIRNAME})

        rm -rf "${TMPDIRNAME}"
    fi

    mv "${installer_dir}/${BASE_FILE_NAME}.spk" "${UPDATE_TARGET}"
}

parse_options "$@"

travis_mark_begin "BUILDING SYNOLOGY PACKAGE"
build_installer
travis_mark_end "BUILDING SYNOLOGY PACKAGE"