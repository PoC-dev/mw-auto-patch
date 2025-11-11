This file is part of *mw-auto-patch*, a shell script for automatic upgrades of MediaWiki instances from diff files.

## License
It is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

It is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with it; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA or get it at http://www.gnu.org/licenses/gpl.html

## Prerequisites
This is mainly to enable GPG verification of downloaded files prior to installation.

- Download keys
```
     wget https://www.mediawiki.org/keys/keys.txt
```
- Import keys
```
     gpg --import keys.txt && rm keys.txt
```
- Delete expired keys
```
     gpg --delete-keys --batch $(gpg --list-keys |grep -FA1 'expired:' |grep -E '^[[:space:]]+[[:xdigit:]]{40}$')
```
- Set trust of the remaining keys to three (I trust marginally).
```
     for KEY in $(gpg --list-keys |grep -E '[[:xdigit:]]{40}' |awk '{print $1}'); do printf "3\nquit\n" |gpg --command-fd 0 --edit-key ${KEY} trust; done
```

## Usage
This script `mw-auto-patch.sh` accepts no command line parameters, searches the hard coded directory */var/www* for MediaWiki instances, determines the currently installed release and upgrades to the next available release. It automatically runs the respective *maintenance/update.php* script.

If the local installation lags behind more than one release, `mw-auto-patch.sh` must be run repeatedly.

### Assumptions
- Script currently has the LTS-release 1.39 (LTS) hard coded.
- Script assumes all instances to be located in */var/www*, and iterates through them.
- Script assumes to be run as the user who owns the web tree. In Debian Linux this is user and group *www-data*.

----
poc@pocnet.net, 2025-11-11
