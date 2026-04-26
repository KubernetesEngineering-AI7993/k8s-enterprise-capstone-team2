FROM python:3.11-slim

WORKDIR /app

# System deps for OpenCV
RUN apt-get update && \
    apt-get install -y --no-install-recommends libgl1 libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

COPY best.pt .

RUN groupadd -g 1000 appuser && \
    useradd -u 1000 -g appuser -m -d /home/appuser -s /usr/sbin/nologin appuser && \
    chown -R 1000:1000 /app

USER 1000:1000

EXPOSE 5001

CMD ["python", "app.py"]
