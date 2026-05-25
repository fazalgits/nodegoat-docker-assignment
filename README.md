# Production-Grade Dockerization: OWASP NodeGoat

This project containerizes the public OWASP NodeGoat Node.js application for a production-style Docker deployment. The application runs on port `4000` and requires MongoDB.

## Part 1: Repository Analysis

- Runtime: Node.js
- Application framework: Express
- Startup command: `node server.js` (`npm start` also runs this)
- Default application port: `4000`
- Database: MongoDB
- Compatible database image: `mongo:4.4`
- Database driver: `mongodb`
- Main configuration file: `config/env/all.js`
- Supported environment variables:
  - `NODE_ENV=production`
  - `PORT=4000`
  - `MONGO_URL=mongodb://mongodb:27017/nodegoat`
  - `MONGODB_URI=mongodb://mongodb:27017/nodegoat`
  - `COOKIE_SECRET`
  - `CRYPTO_KEY`

## Part 2: Dockerfile

The Dockerfile uses:

- Official lightweight `node:12-alpine` images
- Multi-stage build
- Layer caching by copying `package.json` and `package-lock.json` before source code
- Production dependency installation only
- Non-root `node` user
- Default `NODE_ENV`, `PORT`, and `MONGO_URL`
- `EXPOSE 4000`
- Docker `HEALTHCHECK`

## Part 3: Build Docker Image

```bash
docker build -t nodegoat-secure:v1 .
```

Check image size:

```bash
docker images nodegoat-secure:v1
```

## Part 4: Run MongoDB Container

Create a named volume:

```bash
docker volume create mongodb-data
```

Create a Docker network before running containers:

```bash
docker network create nodegoat-network
```

Run MongoDB on the internal network only:

```bash
docker run -d \
  --name mongodb \
  --network nodegoat-network \
  -v mongodb-data:/data/db \
  mongo:4.4
```

MongoDB is not published with `-p` in the hardened version, so it is not exposed publicly.

Compatibility note: the assignment example uses `mongo:7`, but this NodeGoat version uses an older MongoDB Node.js driver. MongoDB 7 removes the legacy `OP_QUERY` protocol used by that driver, which causes login errors. `mongo:4.4` keeps the application functional while preserving the Docker networking, volume, reverse proxy, and hardening requirements.

## Part 5: Custom Docker Network

The custom network is named `nodegoat-network`.

Containers on this network resolve each other by container name. The NodeGoat app connects to MongoDB with:

```text
mongodb://mongodb:27017/nodegoat
```

Inside Docker, do not use `localhost` for MongoDB because `localhost` would point back to the application container itself.

## Part 6: Run Application Container

```bash
docker run -d \
  --name nodegoat-app \
  --network nodegoat-network \
  --read-only \
  --tmpfs /tmp \
  -p 4000:4000 \
  -e NODE_ENV=production \
  -e PORT=4000 \
  -e MONGO_URL=mongodb://mongodb:27017/nodegoat \
  -e COOKIE_SECRET=change-this-cookie-secret \
  -e CRYPTO_KEY=change-this-crypto-key \
  nodegoat-secure:v1
```

Open the app directly:

```text
http://localhost:4000
```

Seed the default users:

```bash
docker exec nodegoat-app node artifacts/db-reset.js
```

Default login:

```text
User Name: admin
Password: Admin_123
```

## Part 7: Reverse Proxy Integration

Run NGINX as a separate container:

```bash
docker run -d \
  --name nodegoat-nginx \
  --network nodegoat-network \
  -p 80:80 \
  -v "$PWD/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:1.27-alpine
```

Open the app through NGINX:

```text
http://localhost
```

The reverse proxy configuration:

- Routes traffic to `nodegoat-app:4000`
- Enables gzip compression
- Adds security headers
- Hides NGINX server tokens

## Part 8: Security Hardening

Security controls implemented:

- Runs as the non-root `node` user
- Uses a read-only application container filesystem
- Uses `tmpfs /tmp` for temporary writes
- Uses Alpine base images
- Installs production dependencies only
- Keeps MongoDB internal to the Docker network
- Avoids hardcoded production secrets by supporting environment variables
- Uses `.dockerignore` to keep unnecessary files out of the image
- Adds reverse proxy security headers

## Part 9: Monitoring and Troubleshooting

Useful commands:

```bash
docker logs nodegoat-app
docker inspect nodegoat-app
docker exec -it nodegoat-app sh
docker top nodegoat-app
docker stats
docker network inspect nodegoat-network
docker volume inspect mongodb-data
```

Check health status:

```bash
docker inspect --format='{{json .State.Health}}' nodegoat-app
```

Common issue: if the app cannot connect to MongoDB, verify both containers are on `nodegoat-network` and that `MONGO_URL` uses `mongodb`, not `localhost`.

## Part 10: Persistent Storage Validation

1. Create data in the application by signing up or changing application data.
2. Stop MongoDB:

```bash
docker stop mongodb
```

3. Remove MongoDB:

```bash
docker rm mongodb
```

4. Recreate MongoDB with the same volume:

```bash
docker run -d \
  --name mongodb \
  --network nodegoat-network \
  -v mongodb-data:/data/db \
  mongo:4.4
```

5. Refresh the application and verify the data still exists.

## Part 11: Image Optimization

Optimization techniques used:

- `node:12-alpine` base image
- Multi-stage Dockerfile
- Production dependencies only
- Docker layer caching
- `.dockerignore` excludes Git history, tests artifacts, local dependencies, and logs
- NPM cache is cleaned after dependency installation

Compare image sizes:

```bash
docker images nodegoat-secure:v1
```

Measured comparison:

- Initial unoptimized image: `nodegoat-unoptimized:v1` = `2.2GB`
- Optimized production image: `nodegoat-secure:v1` = `184MB`

The optimized image is smaller because it uses Alpine, installs production dependencies only, keeps dependency installation in a cacheable layer, and copies only the production runtime dependencies into the final stage.

## Part 12: CI/CD Extension

The workflow `.github/workflows/docker-image.yml`:

- Installs dependencies
- Runs linting
- Builds the Docker image
- Tags with the Git SHA and `latest`
- Pushes to GitHub Container Registry on push events

## Bonus

Optional extensions:

- Multi-architecture builds with Docker Buildx
- Vulnerability scanning with Trivy or Docker Scout
- Auto-healing with restart policies and health checks
- Secret management with Docker secrets or external secret files
