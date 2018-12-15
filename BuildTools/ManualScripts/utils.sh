
function update_changelog () {
	if [[ ! -f "${RELEASE_CHANGELOG_NEWS_FILE}" ]]; then
		echo "  No updates to add to changelog found. Describe updates in ${RELEASE_CHANGELOG_NEWS_FILE}"
		return
	fi

	RELEASE_CHANGEINFO_NEWS=$(cat "${RELEASE_CHANGELOG_NEWS_FILE}" 2>/dev/null)
	if [ ! "x${RELEASE_CHANGEINFO_NEWS}" == "x" ]; then

		echo "${RELEASE_TIMESTAMP} - ${RELEASE_NAME}" > "tmp_changelog.txt"
		echo "==========" >> "tmp_changelog.txt"
		echo "${RELEASE_CHANGEINFO_NEWS}" >> "tmp_changelog.txt"
		echo >> "tmp_changelog.txt"
		cat "${RELEASE_CHANGELOG_FILE}" >> "tmp_changelog.txt"
		cp "tmp_changelog.txt" "${RELEASE_CHANGELOG_FILE}"
		rm "tmp_changelog.txt"
	fi

	RELEASE_CHANGEINFO=$(cat ${RELEASE_CHANGELOG_FILE})
	if [ "x${RELEASE_CHANGEINFO}" == "x" ]; then
		echo "  Warning: No information in changelog file"
	fi
}


function update_git_repo () {
	git checkout "Duplicati/License/VersionTag.txt"
	git checkout "Duplicati/Library/AutoUpdater/AutoUpdateURL.txt"
	git checkout "Duplicati/Library/AutoUpdater/AutoUpdateBuildChannel.txt"
	git add "Updates/build_version.txt"
	git add "${RELEASE_CHANGELOG_FILE}"
	git commit -m "Version bump to v${RELEASE_VERSION}-${RELEASE_NAME}" -m "You can download this build from: " -m "Binaries: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip" -m "Signature file: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip.sig" -m "ASCII signature file: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip.sig.asc" -m "MD5: ${ZIP_MD5}" -m "SHA1: ${ZIP_SHA1}" -m "SHA256: ${ZIP_SHA256}"
	git tag "v${RELEASE_VERSION}-${RELEASE_NAME}"                       -m "You can download this build from: " -m "Binaries: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip" -m "Signature file: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip.sig" -m "ASCII signature file: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip.sig.asc" -m "MD5: ${ZIP_MD5}" -m "SHA1: ${ZIP_SHA1}" -m "SHA256: ${ZIP_SHA256}"
	git push --tags
}

