#!/bin/bash

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }


echo "Importing .env"
source .env


# Constants
restore_dir=$1          # First argument


nc_volume_dir="/var/lib/docker/volumes/nextcloud_nextcloud"
webserverServiceName="nginx"
webserverUser="www-data"
nc_backup_filename="nextcloud-filedir.tar.gz"
nc_db_backup_filename="nextcloud-db.dump"


echo "Backup directory: $backupMainDir"


# Check if parameter(s) given
if [ $# != "1" ]
then
    errorecho "ERROR: No backup dir to restore given, or wrong number of parameters!"
    exit 1
fi


# Check for root
if [ "$(id -u)" != "0" ]
then
    errorecho "ERROR: This script has to be run as root!"
    exit 1
fi


# Check if backup dir exists
if [ ! -d "${restore_dir}" ]
then
	 errorecho "ERROR: Backup ${restore_dir} not found!"
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


# Delete nextcloud files and restore from backup
echo "Deleting old Nextcloud file directory and restoring backup..."
docker run --rm --volumes-from nextcloud_app_1 -v "${restore_dir}":/backup ubuntu bash -c "cd /var/www/html && rm -rf /var/www/html/* && tar xvf /backup/${nc_backup_filename} --strip 3"
echo "Done"
echo


# Restore database
echo "Restoring backup DB: ${restore_dir}/${nc_db_backup_filename}"
echo "copy db backup into db container..."
docker cp "${restore_dir}/${nc_db_backup_filename}" nextcloud_db_1:/tmp/db_backup.sql
echo "dropping db..."
docker-compose exec db dropdb -U "nextcloud_db_user" "nextcloud_db"
echo "restore db from backup..."
docker-compose exec db psql -U "${POSTGRES_USER}" -f /tmp/db_backup.sql postgres
echo "Done"


# Start web server ()
echo "Starting proxy and letsencrypt containers..."
docker-compose up -d proxy letsencrypt-companion
echo "Done"
echo


# Update the system data-fingerprint
#(see https://docs.nextcloud.com/server/15/admin_manual/configuration_server/occ_command.html#maintenance-commands-label)
echo "Updating the system data-fingerprint..."
sudo docker-compose exec --user "${webserverUser}" app php occ maintenance:data-fingerprint
echo "Done"
echo


# Disable maintenance mode
function DisableMaintenanceMode() {
	echo "Switching off maintenance mode..."
	sudo docker-compose exec --user "${webserverUser}" app php occ maintenance:mode --off
	echo "Done"
	echo
}
DisableMaintenanceMode

echo
echo "DONE!"
echo "Backup ${restore_dir} successfully restored."
