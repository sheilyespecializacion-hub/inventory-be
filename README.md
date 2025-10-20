## Inventory Backend

This project provides the backend services for the inventory management
application referenced in the course activity. It exposes a FastAPI based REST
API, connects to a relational database via SQLAlchemy and implements user
authentication.

The following guide summarizes how to run the service locally and how to deploy
it to Google Cloud so it can be consumed by the frontend application hosted at
[`inventory-fe`](https://github.com/johanpina/inventory-fe).

---

## 1. Local development

### 1.1. Requirements

- Python 3.10+
- A PostgreSQL instance (local container or managed database)

### 1.2. Environment variables

Create a `.env` file at the project root with the following variables:

```bash
DATABASE_URL=postgresql+psycopg2://<user>:<password>@<host>:<port>/<database>
SECRET_KEY=<random-string>
ACCESS_TOKEN_EXPIRE_MINUTES=30
ALGORITHM=HS256
```

### 1.3. Setup steps

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head  # creates tables and seeds the default data
uvicorn app.main:app --reload
```

The API will be available at `http://127.0.0.1:8000`.

---

## 2. Google Cloud deployment

The recommended architecture uses **Cloud Run** for the backend and **Cloud SQL
for PostgreSQL** as the managed database. The frontend can then be deployed to
Firebase Hosting or Cloud Run, pointing to the Cloud Run backend URL.

### 2.1. Prerequisites

1. A Google Cloud project with billing enabled.
2. `gcloud` CLI installed and authenticated (`gcloud init`).
3. Docker installed locally (or use Cloud Build).

### 2.2. Provision the database (Cloud SQL)

1. Enable the Cloud SQL Admin API: `gcloud services enable sqladmin.googleapis.com`.
2. Create a PostgreSQL instance (e.g. PostgreSQL 14):

   ```bash
   gcloud sql instances create inventory-sql \
     --database-version=POSTGRES_14 \
     --tier=db-g1-small \
     --region=us-central1
   ```

3. Set the default user password:

   ```bash
   gcloud sql users set-password postgres --instance=inventory-sql --password=<PASSWORD>
   ```

4. Create the application database:

   ```bash
   gcloud sql databases create inventory --instance=inventory-sql
   ```

5. Note the instance connection name (`project:region:inventory-sql`).

### 2.3. Prepare the Docker image

1. Build the container image from this repository:

   ```bash
   gcloud builds submit --tag gcr.io/$(gcloud config get-value project)/inventory-be
   ```

2. Alternatively, build locally and push:

   ```bash
   docker build -t gcr.io/PROJECT_ID/inventory-be .
   docker push gcr.io/PROJECT_ID/inventory-be
   ```

### 2.4. Configure secrets and environment variables

Prepare a file named `.env.prod` with the production values:

```env
DATABASE_URL=postgresql+psycopg2://postgres:<PASSWORD>@127.0.0.1:5432/inventory
SECRET_KEY=<secure-random-string>
ACCESS_TOKEN_EXPIRE_MINUTES=30
ALGORITHM=HS256
```

Store sensitive values securely. You can load them directly from the file during
deployment or, for a more secure approach, create individual secrets in **Secret
Manager** for each variable and reference them in the deployment command.

### 2.5. Deploy to Cloud Run

```bash
gcloud run deploy inventory-backend \
  --image=gcr.io/$(gcloud config get-value project)/inventory-be \
  --platform=managed \
  --region=us-central1 \
  --allow-unauthenticated \
  --set-cloudsql-instances=$(gcloud sql instances describe inventory-sql --format='value(connectionName)') \
  --env-vars-file=.env.prod

If you stored the values in Secret Manager instead of `.env.prod`, replace the
last flag with `--set-secrets=DATABASE_URL=inventory-db-url:latest,...` for each
secret you created.
```

This command mounts the Cloud SQL instance using the Cloud SQL Auth Proxy
integration and injects the environment variables from Secret Manager.

### 2.6. Run the database migrations

Once the service is deployed, execute Alembic migrations against the Cloud SQL
instance. The easiest approach is to run the migration locally using the Cloud
SQL proxy:

```bash
gcloud sql connect inventory-sql --user=postgres --quiet
# inside the psql shell create the tables if needed:
\q

cloud_sql_proxy --instances=$(gcloud sql instances describe inventory-sql --format='value(connectionName)')=127.0.0.1:5432
DATABASE_URL=postgresql+psycopg2://postgres:<PASSWORD>@127.0.0.1:5432/inventory alembic upgrade head
```

The migration seeds the demo data required by the activity.

### 2.7. Configure the frontend

Set the environment variable in the frontend repository (`inventory-fe`):

```env
VITE_API_URL=https://<cloud-run-url>
```

Rebuild and redeploy the frontend (for example, to Firebase Hosting or Cloud
Run). The application will now communicate with the deployed backend.

---

## 3. Troubleshooting

- **Authentication errors**: verify the `SECRET_KEY` and token expiry values are
  identical between local and production environments.
- **Database connection failures**: confirm the Cloud Run service account has
  the `Cloud SQL Client` role and that the instance connection name is set
  correctly.
- **CORS issues**: if deploying the frontend to a different domain, update the
  CORS configuration in `app/main.py` accordingly.

With these steps the inventory management application will be fully deployed on
Google Cloud, ready for the frontend to consume the backend API.