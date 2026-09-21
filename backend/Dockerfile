FROM python:3.14-slim

WORKDIR /app

# Apply Debian security fixes even between upstream Python image refreshes.
RUN apt-get update && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools \
    && pip install --no-cache-dir -r requirements.txt \
    && pip check \
    && pip uninstall -y setuptools pip \
    && python -c "import ensurepip, pathlib, shutil; shutil.rmtree(pathlib.Path(ensurepip.__file__).parent)"
# Runtime uses installed application packages, not pip/setuptools or ensurepip's
# bundled installer wheels (which otherwise retain old vendored dependencies).

COPY app/ app/

RUN useradd --create-home --uid 10001 watchdoo
USER watchdoo

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
