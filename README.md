# nextcloud
Install nextcloud complete with PostgreSQL database, security certificates with TrueCrypt

## Installation
git clone repository
cd repository
Create a .env file with
```
POSTGRES_USER=
POSTGRES_PASSWORD=
HOST=
EMAIL=
```

```
docker-compose build --pull
docker-compose up -d
```

