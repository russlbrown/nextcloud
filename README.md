# nextcloud
Install nextcloud complete with PostgreSQL database, security certificates with TrueCrypt

## Installation
git clone repository
cd repository
Create a .env file with
```
POSTGRES_PASSWORD=
POSTGRES_USER=
POSTGRES_DB=
NEXTCLOUD_ADMIN_USER=
NEXTCLOUD_ADMIN_PASSWORD=
DOMAIN_NAME=
EMAIL=
```

```
docker-compose build --pull
docker-compose up -d
```

