# nextcloud
Install nextcloud complete with PostgreSQL database, security certificates with TrueCrypt

## Installation
git clone repository
cd repository
Create a .env file with
```
POSTGRES_DB=nextcloud_db
POSTGRES_USER=nextcloud_db_user
POSTGRES_PASSWORD=

# The url of your website. i.e. nextcloud.dyndns.com
HOST=

# Your email address for use with Let'sEncrypt
EMAIL=
```

```
docker-compose build --pull
docker-compose up -d
```

To use the nextcloud command line tool:
`docker-compose exec --user www-data app php occ`

## Creating a Backup
1. Create a database dump and save it to your backup location.
2. Copy the nextcloud_nextcloud volume to your backup location.
