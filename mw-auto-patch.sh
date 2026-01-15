#!/bin/sh

# Copyright 2025, 2026, Patrik Schindler <poc@pocnet.net>.
#
# This file is part of mw-auto-patch, a shell script for automatic upgrades of
# MediaWiki instances from diff files. The original repository is located on
# GitHub: https://github.com/PoC-dev/mw-auto-patch
#
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# It is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# it; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA 02111-1307 USA or get it at
# http://www.gnu.org/licenses/gpl.html

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

		echo "Found Mediawiki ${V_MAJ_MIN}.${V_PATCH} in ${DOCUMENT_ROOT}."

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
			echo "Got new patch file, updating to ${V_MAJ_MIN}.$((V_PATCH + 1))."
			cd "${DOCUMENT_ROOT}" && {
				zcat "${TMPDIR}/${NEXTFILE}" |patch -p1
				php -q maintenance/update.php --quick
				cd -
			}
		fi
	fi
done

# -EOF-
