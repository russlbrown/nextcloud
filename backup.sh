#!/bin/bash

#
# Bash script for creating backups of Nextcloud.
# Usage:
# 	- With backup directory specified in the script:  ./NextcloudBackup.sh
# 	- With backup directory specified by parameter: ./NextcloudBackup.sh <BackupDirectory> (e.g. ./NextcloudBackup.sh /media/hdd/nextcloud_backup)
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
echo "POSTGRES_DB: $POSTGRES_DB"

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
backupdir="${backupMainDir}/${currentDate}"
nextcloudFileDir="/var/lib/docker/volumes/nextcloud_nextcloud"
webserverServiceName="nginx"
nextcloudDatabase="$POSTGRES_DB"
dbUser="$POSTGRES_USER"
dbPassword="$POSTGRES_PASSWORD"
webserverUser="www-data"
maxNrOfBackups=7
fileNameBackupFileDir="nextcloud-filedir.tar.gz"
fileNameBackupDb="nextcloud-db.dump"


function DisableMaintenanceMode() {
	echo "Switching off maintenance mode..."
	sudo docker-compose exec --user "${webserverUser}" app php occ maintenance:mode --off
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

#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
	errorecho "ERROR: This script has to be run as root!"
	exit 1
fi

#
# Check if backup dir already exists
#
if [ ! -d "${backupdir}" ]
then
	mkdir -p "${backupdir}"
else
	errorecho "ERROR: The backup directory ${backupdir} already exists!"
	exit 1
fi

#
# Set maintenance mode
#
echo "Set maintenance mode for Nextcloud..."
sudo docker-compose exec --user "${webserverUser}" app php occ maintenance:mode --on
echo "Done"
echo

#
# Stop web server
#
echo "Stopping proxy and letsencrypt-companion docker containers..."
# systemctl stop "${webserverServiceName}"
docker-compose stop proxy letsencrypt-companion
echo "Done"
echo


#
# Backup file directory
#
echo "Creating backup of Nextcloud file directory..."
# tar -cpzf "${backupdir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}" .
docker run --rm --volumes-from nextcloud_app_1 -v "${backupdir}":/backup ubuntu tar cvf /backup/"${fileNameBackupFileDir}" /var/www/html
echo "Done"
echo

#### MEAT AND POTATOES #########################################################################################
#
# Backup DB
#
echo "Backup Nextcloud database..."
# MySQL/MariaDB:
# mysqldump --single-transaction -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" > "${backupdir}/${fileNameBackupDb}"

# PostgreSQL (uncomment if you are using PostgreSQL as Nextcloud database)
#### docker run --rm --volumes-from nextcloud_db_1 -v "${backupdir}":/backup postgres:alpine pg_dump -Fc "${nextcloudDatabase}" -U "${dbUser}" -f /backup/"${fileNameBackupDb}"
###docker-compose exec -T db pg_dump -Fc "${nextcloudDatabase}" -U "${dbUser}" > "${backupdir}/${fileNameBackupDb}"
## docker-compose exec -u "${dbUser}" db pg_dump -Fc "${nextcloudDatabase}" > "${backupdir}/${fileNameBackupDb}"

# Try 1
# docker-compose exec -u nextcloud_db_user db pg_dump -Fc nextcloud_db > try1.dump
# 	unable to find user nextcloud_db_user: no matching entries in passwd file

# Try 2
# docker-compose exec db pg_dump -U nextcloud_db_user -Fc nextcloud_db > local/try2.dump
#   This Made what looks like a valid dump. It has lots of special characters in it.

# Try 3
# docker-compose exec -T db pg_dump -U nextcloud_db_user -Fc nextcloud_db > local/try3.dump
#   This Made what looks like a valid dump. It has lots of special characters in it.


##########################################
# Try 4 (this worked inside docker)
docker-compose exec -T db pg_dumpall -U nextcloud_db_user > pg_dumpall_db.sql
###################################



## Trying backup and restore from inside a docker shell i.e. backup doesnt leave the container

# This looks promising: pg_restore -U nextcloud_db_user --create --dbname=nextcloud_db < db.dump

# These two commands in succession seem to work. nextcloud broke and didn't recover tough.
# dropdb -U nextcloud_db_user  nextcloud_db
# pg_restore -U nextcloud_db_user --create < db.dump


echo "Done"
echo

#
# Start web server ()
#
echo "Starting proxy and letsencrypt containers..."
# systemctl start "${webserverServiceName}"
docker-compose up -d proxy letsencrypt-companion
echo "Done"
echo

#
# Disable maintenance mode
#
DisableMaintenanceMode

#
# Delete old backups
#
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
echo "Backup created: ${backupdir}"

