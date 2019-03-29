#!/bin/bash

#
# Bash script for creating backups of Nextcloud.
# Usage:
# 	- With backup directory specified in the script:  ./NextcloudBackup.sh
# 	- With backup directory specified by parameter: ./NextcloudBackup.sh <backup_directory> (e.g. ./NextcloudBackup.sh /media/hdd/nextcloud_backup)
#
# The script is based on an installation of Nextcloud using nginx and MariaDB, see https://decatec.de/home-server/nextcloud-auf-ubuntu-server-18-04-lts-mit-nginx-mariadb-php-lets-encrypt-redis-und-fail2ban/
#

#
# IMPORTANT
# You have to customize this script (directories, users, etc.) for your actual environment.
# All entries which need to be customized are tagged with "TODO".
#

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

echo "Importing .env"
source .env

# Variables
backupMainDir=$1

if [ -z "$backupMainDir" ]; then
	# TODO: The directory where you store the Nextcloud backups (when not specified by args)
    backupMainDir="$BACKUP_DIR"
fi

echo "Backup directory: $backupMainDir"

if [ ! -d "$backupMainDir" ]; then
	errorecho "ERROR: Backup directory ${backupMainDir} does not exist."
	exit 1
fi

currentDate=$(date +"%Y%m%d_%H%M%S")
# The actual directory of the current backup - this is a subdirectory of the main directory above with a timestamp

backup_dir="${backupMainDir}/${currentDate}"
nc_volume_dir="/var/lib/docker/volumes/nextcloud_nextcloud"
webserverServiceName="nginx"
webserverUser="www-data"
maxNrOfBackups=7
nc_backup_filename="nextcloud-filedir.tar.gz"
nc_db_backup_filename="nextcloud-db.dump"


function DisableMaintenanceMode() {
	echo "Switching off maintenance mode..."
	sudo docker-compose exec -T --user "${webserverUser}" app php occ maintenance:mode --off
	echo "Done"
	echo
}

# Capture CTRL+C
trap CtrlC INT

function CtrlC() {
	read -p "Backup cancelled. Keep maintenance mode? [y/n] " -n 1 -r
	echo

	if ! [[ $REPLY =~ ^[Yy]$ ]]
	then
		DisableMaintenanceMode
	else
		echo "Maintenance mode still enabled."
	fi

	exit 1
}


# Check for root
if [ "$(id -u)" != "0" ]
then
	errorecho "ERROR: This script has to be run as root!"
	exit 1
fi


# Check if backup dir already exists
if [ ! -d "${backup_dir}" ]
then
	mkdir -p "${backup_dir}"
else
	errorecho "ERROR: The backup directory ${backup_dir} already exists!"
	exit 1
fi


# Set maintenance mode
echo "Set maintenance mode for Nextcloud..."
sudo docker-compose exec -T --user "${webserverUser}" app php occ maintenance:mode --on
echo "Done"
echo


# Stop web server
echo "Stopping proxy and letsencrypt-companion docker containers..."
docker-compose stop proxy letsencrypt-companion
echo "Done"
echo


#
# Backup file directory
#
echo "Creating backup of Nextcloud file directory..."
# tar -cpzf "${backup_dir}/${nc_backup_filename}" -C "${nc_volume_dir}" .
docker run --rm --volumes-from nextcloud_app_1 -v "${backup_dir}":/backup ubuntu tar -cf /backup/"${nc_backup_filename}" /var/www/html
echo "Done"
echo


# Backup DB
echo "Backup Nextcloud database..."
docker-compose exec -T db pg_dumpall -U "${POSTGRES_USER}" > "${backup_dir}/${nc_db_backup_filename}"
echo "Done"
echo


# Start web server ()
echo "Starting proxy and letsencrypt containers..."
# systemctl start "${webserverServiceName}"
docker-compose up -d proxy letsencrypt-companion
echo "Done"
echo


# Disable maintenance mode
DisableMaintenanceMode


# Delete old backups
if (( ${maxNrOfBackups} != 0 ))
then
	nrOfBackups=$(ls -l ${backupMainDir} | grep -c ^d)

	if (( ${nrOfBackups} > ${maxNrOfBackups} ))
	then
		echo "Removing old backups..."
		ls -t ${backupMainDir} | tail -$(( nrOfBackups - maxNrOfBackups )) | while read dirToRemove; do
			echo "${dirToRemove}"
			rm -r ${backupMainDir}/${dirToRemove}
			echo "Done"
			echo
		done
	fi
fi

echo
echo "DONE!"
echo "Backup created: ${backup_dir}"

