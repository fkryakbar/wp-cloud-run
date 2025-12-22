# WordPress Production-Ready Docker Image

Dockerfile yang dioptimalkan untuk menjalankan WordPress di production environment, khususnya untuk Google Cloud Run atau container orchestration platform lainnya.

## 🚀 Features

### PHP Extensions

- **GD** - Image manipulation dengan Freetype, JPEG, WebP support
- **MySQLi & PDO_MySQL** - Database connectivity
- **Redis & Memcached** - Caching support
- **OPcache** - PHP bytecode caching untuk performa optimal
- **Intl** - Internationalization support
- **Zip** - Archive handling
- **BCMath** - Arbitrary precision mathematics
- **Exif** - Image metadata reading

### Security Hardening

- Security headers (X-Content-Type-Options, X-Frame-Options, X-XSS-Protection)
- PHP exposure disabled
- Apache version hidden
- Secure session cookie settings
- Proper file permissions

### Performance Optimization

- OPcache enabled dengan konfigurasi optimal
- Gzip compression (mod_deflate)
- Browser caching (mod_expires)
- Optimized PHP memory settings

### Cloud Run Compatibility

- Dynamic PORT binding
- Auto-generated WordPress security keys
- Health check endpoint
- Stateless-ready design

## 📁 Directory Structure

```
wp-cloud-run/
├── Dockerfile                    # Main Dockerfile
├── docker-entrypoint-wrapper.sh  # Custom entrypoint for Cloud Run
├── .dockerignore                 # Files to exclude from build
├── .env.example                  # Environment variables template
└── README.md                     # This file
```

## 🔧 Environment Variables

| Variable                 | Description             | Default   |
| ------------------------ | ----------------------- | --------- |
| `WORDPRESS_DB_HOST`      | Database host           | localhost |
| `WORDPRESS_DB_USER`      | Database username       | wordpress |
| `WORDPRESS_DB_PASSWORD`  | Database password       | wordpress |
| `WORDPRESS_DB_NAME`      | Database name           | wordpress |
| `WORDPRESS_TABLE_PREFIX` | Table prefix            | wp\_      |
| `WORDPRESS_DEBUG`        | Enable debug mode       | false     |
| `PORT`                   | Server port (Cloud Run) | 80        |

## 🏗️ Build & Run

### Local Build

```bash
# Build image
docker build -t wordpress-production .

# Run locally
docker run -d \
  -p 8080:80 \
  -e WORDPRESS_DB_HOST=host.docker.internal:3306 \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=secret \
  -e WORDPRESS_DB_NAME=wordpress \
  wordpress-production
```

### Deploy to Cloud Run

```bash
# Build and push to Container Registry
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/wordpress-production

# Deploy to Cloud Run
gcloud run deploy wordpress \
  --image gcr.io/YOUR_PROJECT_ID/wordpress-production \
  --platform managed \
  --region asia-southeast1 \
  --allow-unauthenticated \
  --set-env-vars "WORDPRESS_DB_HOST=YOUR_DB_HOST" \
  --set-env-vars "WORDPRESS_DB_USER=YOUR_DB_USER" \
  --set-env-vars "WORDPRESS_DB_PASSWORD=YOUR_DB_PASSWORD" \
  --set-env-vars "WORDPRESS_DB_NAME=YOUR_DB_NAME"
```

## 📦 Adding Custom Plugins/Themes

Untuk menambahkan plugin atau tema custom, buat folder dan copy ke dalam Dockerfile:

```dockerfile
# Di akhir Dockerfile, sebelum ENTRYPOINT
COPY ./wp-content/plugins/my-plugin /var/www/html/wp-content/plugins/my-plugin
COPY ./wp-content/themes/my-theme /var/www/html/wp-content/themes/my-theme
```

## ⚠️ Important Notes

### Media Uploads

Untuk production di Cloud Run, gunakan cloud storage untuk media uploads:

- **Google Cloud Storage** dengan plugin seperti WP-Stateless
- **AWS S3** dengan plugin S3 Uploads

### Database

Gunakan managed database seperti:

- **Cloud SQL** (Google Cloud)
- **RDS** (AWS)
- **PlanetScale** atau **Neon** (Serverless options)

### Caching

Untuk performa optimal, tambahkan:

- **Redis/Memcached** untuk object caching
- **CDN** seperti Cloudflare untuk static assets

## 📝 License

MIT License
