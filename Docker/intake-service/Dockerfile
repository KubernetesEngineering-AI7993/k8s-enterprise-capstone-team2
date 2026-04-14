FROM python:3.11-slim

RUN apt-get update && apt-get install -y libgl1 libglib2.0-0 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install flask opencv-python-headless

COPY images/ /app/images/
COPY app.py /app/

EXPOSE 5000

CMD ["python", "app.py"]