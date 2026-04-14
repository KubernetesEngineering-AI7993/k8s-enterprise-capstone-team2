from flask import Flask, jsonify
from ultralytics import YOLO
import cv2
import numpy as np
import requests
import os

app = Flask(__name__)

# --- Config ---
INTAKE_URL = os.environ.get("INTAKE_URL", "http://intake-service:5000")
MODEL_PATH = os.environ.get("MODEL_PATH", "best.pt")
CONFIDENCE_THRESHOLD = float(os.environ.get("CONFIDENCE_THRESHOLD", "0.25"))

# --- Load model once at startup ---
print(f"Loading YOLO model from {MODEL_PATH} ...")
model = YOLO(MODEL_PATH)
print("Model loaded.")


def fetch_frame():
    """Grab a single JPEG frame from the intake service."""
    resp = requests.get(f"{INTAKE_URL}/frame", timeout=5)
    resp.raise_for_status()
    arr = np.frombuffer(resp.content, dtype=np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    return frame


@app.route("/detect", methods=["POST"])
def detect():
    # 1. Get a frame from intake
    frame = fetch_frame()
    if frame is None:
        return jsonify({"error": "Could not fetch frame"}), 502

    # 2. Run inference
    results = model.predict(frame, conf=CONFIDENCE_THRESHOLD, verbose=False)

    # 3. Parse results into the format the dashboard expects
    detections = []
    for result in results:
        boxes = result.boxes
        for i in range(len(boxes)):
            cls_id = int(boxes.cls[i])
            conf = round(float(boxes.conf[i]), 2)
            x1, y1, x2, y2 = boxes.xyxy[i].tolist()
            detections.append({
                "class": model.names[cls_id],
                "confidence": conf,
                "bbox": [int(x1), int(y1), int(x2 - x1), int(y2 - y1)]
            })

    return jsonify({"detections": detections})


@app.route("/health")
def health():
    return jsonify({"status": "ok", "model": MODEL_PATH})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
