-- Runs only on first boot (empty mysql-data volume).
-- Official mysql image creates MYSQL_USER before scripts in /docker-entrypoint-initdb.d.

CREATE DATABASE IF NOT EXISTS marketplace CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS job_portal CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant app DBs to MYSQL_USER (devminds). Image creates this user before init scripts.
GRANT ALL PRIVILEGES ON marketplace.* TO 'devminds'@'%';
GRANT ALL PRIVILEGES ON job_portal.* TO 'devminds'@'%';

FLUSH PRIVILEGES;