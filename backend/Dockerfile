FROM python:3.14-slim

WORKDIR /app

# Apply Debian security fixes even between upstream Python image refreshes.
RUN apt-get update && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools \
    && pip install --no-cache-dir -r requirements.txt

COPY app/ app/

RUN useradd --create-home --uid 10001 watchdoo
USER watchdoo

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
