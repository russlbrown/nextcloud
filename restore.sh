#!/bin/bash

echo "Importing .env"
source .env


# Constants
restore=$1          # First argument
backupMainDir=$2    # Second Argument

if [ -z "$backupMainDir" ]; then
    backupMainDir="/media/russ/silver_hdd/nextcloud_backups"
fi

defaultBackupMainDir="$BACKUP_DIR"
currentRestoreDir="${backupMainDir}/${restore}"
nextcloudFileDir="/var/lib/docker/volumes/nextcloud_nextcloud"
webserverServiceName="nginx"
nextcloudDatabase="$POSTGRES_DB"
dbUser="$POSTGRES_USER"
dbPassword="$POSTGRES_PASSWORD"
webserverUser="www-data"
fileNameBackupFileDir="nextcloud-filedir.tar.gz"
fileNameBackupDb="nextcloud-db.dump"





# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }


echo "Backup directory: $backupMainDir"


# Check if parameter(s) given
if [ $# != "1" ] && [ $# != "2" ]
then
    errorecho "ERROR: No backup name to restore given, or wrong number of parameters!"
    errorecho "Usage: NextcloudRestore.sh 'BackupDate' ['BackupDirectory']"
    exit 1
fi


# Check for root
if [ "$(id -u)" != "0" ]
then
    errorecho "ERROR: This script has to be run as root!"
    exit 1
fi


# Check if backup dir exists
if [ ! -d "${currentRestoreDir}" ]
then
	 errorecho "ERROR: Backup ${restore} not found!"
    exit 1
fi


# Set maintenance mode
echo "Set maintenance mode for Nextcloud..."
sudo docker-compose exec --user "${webserverUser}" app php occ maintenance:mode --on
echo "Done"
echo


# Stop web server
echo "Stopping proxy and letsencrypt-companion docker containers..."
# systemctl stop "${webserverServiceName}"
docker-compose stop proxy letsencrypt-companion
echo "Done"
echo


# # Delete old Nextcloud direcories

# File directory
echo "Deleting old Nextcloud file directory and restoring backup..."
# rm -r "${nextcloudFileDir}"
# mkdir -p "${nextcloudFileDir}"
docker run --rm --volumes-from nextcloud_app_1 -v "${currentRestoreDir}":/backup ubuntu bash -c "cd /var/www/html && rm -rf /var/www/html/* && tar xvf /backup/${fileNameBackupFileDir} --strip 3"

echo "Done"
echo

# # Restore database
 echo "Dropping old Nextcloud DB..."
 sudo docker-compose exec db dropdb -U "${dbUser}" "${nextcloudDatabase}"
# # PostgreSQL (uncomment if you are using PostgreSQL as Nextcloud database)
 echo "Done"
# echo

# echo "Creating new DB for Nextcloud..."
# # PostgreSQL (uncomment if you are using PostgreSQL as Nextcloud database)
# # sudo -u postgres psql -c "CREATE DATABASE ${nextcloudDatabase} WITH OWNER ${dbUser} TEMPLATE template0 ENCODING \"UTF8\";"
# sudo docker-compose exec db createdb --username="${dbUser}" --owner="${dbUser}" --template=template0 --encoding=UTF8 "${nextcloudDatabase}"
# echo "Done"
# echo

echo "Restoring backup DB: ${currentRestoreDir}/${fileNameBackupDb}"
# # PostgreSQL (uncomment if you are using PostgreSQL as Nextcloud database)
# # sudo -u postgres psql "${nextcloudDatabase}" < "${currentRestoreDir}/${fileNameBackupDb}"
# sudo docker-compose exec --user "${dbUser}" db psql "${nextcloudDatabase}" < "${currentRestoreDir}/${fileNameBackupDb}"
docker-compose exec -T -u "${dbuser}" db pg_restore -C -d postgres < "${currentRestoreDir}/${fileNameBackupDb}"
##docker run --rm --volumes-from nextcloud_db_1 -v "${currentRestoreDir}":/backup postgres:alpine pg_restore -C -d "${nextcloudDatabase}" /backup/"${fileNameBackupDb}"
echo "Done"

#
# Start web server ()
#
echo "Starting proxy and letsencrypt containers..."
# systemctl start "${webserverServiceName}"
docker-compose up -d proxy letsencrypt-companion
echo "Done"
echo

#
# Set directory permissions
#
###echo "Setting directory permissions..."
###chown -R "${webserverUser}":"${webserverUser}" "${nextcloudFileDir}"
# chown -R "${webserverUser}":"${webserverUser}" "${nextcloudDataDir}"
# TOOD: Uncomment if you use local external storage
#chown -R "${webserverUser}":"${webserverUser}" "${nextcloudLocalExternalDataDir}"
###echo "Done"
###echo

#
# Update the system data-fingerprint (see https://docs.nextcloud.com/server/15/admin_manual/configuration_server/occ_command.html#maintenance-commands-label)
#
echo "Updating the system data-fingerprint..."
# sudo -u "${webserverUser}" php ${nextcloudFileDir}/occ maintenance:data-fingerprint
sudo docker-compose exec --user "${webserverUser}" app php occ maintenance:data-fingerprint
echo "Done"
echo

#
# Disable maintenance mode
#

function DisableMaintenanceMode() {
	echo "Switching off maintenance mode..."
	sudo docker-compose exec --user "${webserverUser}" app php occ maintenance:mode --off
	echo "Done"
	echo
}
DisableMaintenanceMode

echo
echo "DONE!"
echo "Backup ${restore} successfully restored."
