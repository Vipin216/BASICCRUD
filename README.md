# NoteSpace — Django CRUD Notes

A small, beginner friendly notes app for demonstrating database operations. It uses Django templates and the Django ORM, with PostgreSQL as its database. The app has no user accounts.

## Requirements

- Python 3.10 or newer
- PostgreSQL installed and running locally
- For Linux production instances, Gunicorn is included as the WSGI server

## Local setup

1. Create a PostgreSQL database named `notes_db` (for example, with `createdb notes_db`) and a database user with permission to use it.
2. Create and activate a virtual environment:

   ```powershell
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   ```

   On macOS/Linux, activate it with `source .venv/bin/activate`.
3. Install the Python dependencies:

   ```shell
   python -m pip install -r requirements.txt
   ```

4. Set the database environment variables for your local PostgreSQL instance. `DB_NAME` defaults to `notes_db`, `DB_USER` to `postgres`, `DB_HOST` to `localhost`, and `DB_PORT` to `5432`. Set `DB_PASSWORD` to the password for that PostgreSQL user. For example in PowerShell:

   ```powershell
   $env:DB_NAME = "notes_db"
   $env:DB_USER = "postgres"
   $env:DB_PASSWORD = "your-local-postgres-password"
   ```

   Credentials are read from the environment and are not stored in the project. `DJANGO_SECRET_KEY` and `DJANGO_DEBUG` can also be set in the environment for local overrides.
5. Create the database tables and start Django:

   ```shell
   python manage.py migrate
   python manage.py runserver
   ```

6. Open <http://127.0.0.1:8000/>.

## Production configuration

The app uses PostgreSQL by default. For a production run, set `DJANGO_DEBUG=0`, `DJANGO_SECRET_KEY` to a long random secret, and `DJANGO_ALLOWED_HOSTS` to a comma-separated list of the host names users will visit. Set `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, and `DB_PORT` for the shared PostgreSQL database. Do not use the local fallback secret in production. Production mode refuses to start without an explicit secret and host list.

Install the requirements on the Linux app instance, run `python manage.py migrate` once for the release, then run `python manage.py collectstatic --noinput`. WhiteNoise serves the collected static files from each app instance. Start the WSGI app with `gunicorn notes_project.wsgi:application --bind 0.0.0.0:8000`. Put the app behind your existing HTTPS load balancer; the default production settings honor its `X-Forwarded-Proto` header and redirect HTTP requests to HTTPS. If TLS is not terminated in front of the app, set `DJANGO_SECURE_SSL_REDIRECT=0` and arrange HTTPS before enabling secure cookies for real users.

For an Auto Scaling Group, every instance must receive the same app version and environment configuration, and all instances must connect to the same PostgreSQL database. Run migrations once per release rather than in every instance's startup process. The project can run behind an existing load balancer on port 8000; configure its health check to use `/`.

## Amazon Linux 2023 launch-template user data

The template at `deploy/amazon-linux-2023-user-data.sh` is for the public HTTPS repository `https://github.com/Vipin216/BASICCRUD.git` on its `main` branch. It uses the RDS endpoint, `postgres` database/user, and port 5432 from the supplied connection command. Replace the Django secret, allowed host, and database password in the script in the launch-template editor. Do not commit a copy containing real credentials. The script downloads the RDS global CA bundle and configures PostgreSQL `verify-full` TLS. AL2023 keeps its system `python3` at 3.9, so it explicitly installs and uses Python 3.11. [AWS AL2023 Python versions](https://docs.aws.amazon.com/linux/al2023/ug/python.html), [RDS PostgreSQL SSL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html)

At launch the script writes the Django and PostgreSQL settings to `/etc/notesapp.env` with restricted file permissions, installs Git/Python/dependencies, collects static files, and starts Gunicorn on port 8000. For this test setup, values are entered in launch-template user data, so AWS users with permission to view that template or instance user data can read them. Do not commit real values to Git or reuse this test password elsewhere.

The instances need outbound access to the Git host and Python package index. The load balancer security group must be able to reach port 8000 on the instance security group. Migrations are intentionally not run during boot: run `python manage.py migrate` once for a release before rolling the ASG.

User data runs when new instances launch. To deploy a newer release tag to the whole ASG, make a new launch-template version with the updated tag and start an instance refresh; existing instances do not update just because a Git commit was pushed. AWS documents the 16 KB user-data limit and instance-refresh rollout flow [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html) and [here](https://docs.aws.amazon.com/autoscaling/ec2/userguide/start-instance-refresh.html).

## Run tests

With the virtual environment active and PostgreSQL configured as above:

```shell
python manage.py test
```

The tests cover listing, detail, create, edit, delete confirmation, blank-field validation, and missing-note responses. Django creates and removes a temporary test database automatically. If PostgreSQL is not available on your computer, the same tests can run using Django's built-in SQLite backend:

```powershell
$env:DB_ENGINE = "sqlite"
python manage.py test
```

PostgreSQL remains the normal application database; `DB_ENGINE=sqlite` is only a local convenience for testing without installing PostgreSQL.

## How the CRUD actions map to SQL

The views use `Note.objects` and `ModelForm`; Django translates those ORM calls into SQL for PostgreSQL:

- **Create** — `form.save()` inserts a row (`INSERT`).
- **List and detail** — `Note.objects.all()` and the lookup by primary key select rows (`SELECT`).
- **Edit** — saving a form with an existing note instance updates its row (`UPDATE`).
- **Delete** — `note.delete()` removes the row after the user confirms with a POST (`DELETE`).

The migration creates the `notes_note` table and its columns. `title` is limited to 200 characters, and both title and content must contain non-whitespace text.
