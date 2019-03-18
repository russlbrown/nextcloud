docker run --rm --volumes-from nextcloud_app_1 -v /home/russ/nextcloud:/backup ubuntu tar cvf /backup/backup.tar /var/www/html
