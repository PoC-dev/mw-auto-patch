#!/bin/sh

set -e

# Create temporary work directory for downloads. Automatically clean up on exit.
TMPDIR=$(mktemp -d '/tmp/mw-auto-patch.XXXXXXXXXX')
trap '{ rm -rf "${TMPDIR}"; }' EXIT

for MW_RELEASE_NOTES in $(find /var/www -maxdepth 3 -type f -a -name 'RELEASE-NOTES-*'); do
	DOCUMENT_ROOT="$(dirname "${MW_RELEASE_NOTES}")"
	V_INSTALLED="$(grep -E '^[=]+ MediaWiki 1\.39\.[0-9]{1,3} [=]+$' "${MW_RELEASE_NOTES}" |awk '{print $3}' |head -1)"

	# Is this a mediawiki instance?
	if [ -n "${V_INSTALLED}" ]; then
		V_MAJ_MIN="$(echo "${V_INSTALLED}" |sed -E 's/^([0-9]\.[0-9]{1,2})\.[0-9]{1,3}$/\1/')"
		V_PATCH="$(echo "${V_INSTALLED}" |sed -E 's/^[0-9]\.[0-9]{1,2}\.([0-9]{1,3})$/\1/')"
		NEXTFILE="$(printf "mediawiki-%s.%d.patch.gz" "${V_MAJ_MIN}" $((V_PATCH + 1)))"

		echo "Found Mediawiki ${V_MAJ_MIN}.${V_PATCH} in ${DOCUMENT_ROOT}. Updating to ${V_MAJ_MIN}.$((V_PATCH + 1))."

		# Try to download new release, if not already existent. Go to next DOCUMENT_ROOT if download error happened. Most likely a 404.
		if [ ! -f "${TMPDIR}/${NEXTFILE}" ]; then
			wget --quiet --directory-prefix="${TMPDIR}" "https://releases.wikimedia.org/mediawiki/${V_MAJ_MIN}/${NEXTFILE}" || true
			wget --quiet --directory-prefix="${TMPDIR}" "https://releases.wikimedia.org/mediawiki/${V_MAJ_MIN}/${NEXTFILE}.sig" || true

			if [ -s "${TMPDIR}/${NEXTFILE}" ] && [ -s "${TMPDIR}/${NEXTFILE}.sig" ]; then
				# https://stackoverflow.com/questions/14167995/how-to-use-gnu-privacy-guard-to-verify-authenticity-of-mediawiki-download
				gpg --verify "${TMPDIR}/${NEXTFILE}.sig" 2>/dev/null || {
					echo "GPG signature verification failed for file ${TMPDIR}/${NEXTFILE}"
					exit 1
				}
			fi
		fi

		if [ -s "${TMPDIR}/${NEXTFILE}" ]; then
			cd "${DOCUMENT_ROOT}" && {
				zcat "${TMPDIR}/${NEXTFILE}" |patch -p1
				php -q maintenance/update.php --quick 
				cd -
			}
		fi
	fi
done

# -EOF-
