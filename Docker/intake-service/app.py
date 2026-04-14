from flask import Flask, Response, jsonify
import cv2
import gc
import os
import time
import random

app = Flask(__name__)

DATASET_PATH = "/app/images"
STREAM_WIDTH = 640

image_files = sorted([
    os.path.join(DATASET_PATH, f)
    for f in os.listdir(DATASET_PATH)
    if f.lower().endswith(('.jpg', '.jpeg', '.png'))
])

# Pre-encode resized stream frames at startup (JPEG bytes, not raw pixels)
# This uses ~30MB instead of ~2GB for raw pixel arrays
print(f"Pre-encoding {len(image_files)} stream frames...")
stream_frames = []
for i, img_path in enumerate(image_files):
    frame = cv2.imread(img_path)
    if frame is None:
        continue
    h, w = frame.shape[:2]
    scale = STREAM_WIDTH / w
    small = cv2.resize(frame, (STREAM_WIDTH, int(h * scale)))
    _, buf = cv2.imencode(".jpg", small, [cv2.IMWRITE_JPEG_QUALITY, 70])
    stream_frames.append(buf.tobytes())
    del frame, small, buf
    if i % 50 == 0:
        gc.collect()
gc.collect()
print(f"Ready. {len(stream_frames)} frames cached.")


@app.route("/stream")
def stream():
    def generate():
        while True:
            for jpeg_bytes in stream_frames:
                yield (b"--frame\r\n"
                       b"Content-Type: image/jpeg\r\n\r\n" +
                       jpeg_bytes + b"\r\n")
                time.sleep(0.3)
    return Response(generate(),
                    mimetype="multipart/x-mixed-replace; boundary=frame")


@app.route("/frame")
def single_frame():
    """Serve a full-res frame as JPEG for the detection service"""
    img_path = random.choice(image_files)
    frame = cv2.imread(img_path)
    if frame is None:
        return "No frame", 500
    _, buffer = cv2.imencode(".jpg", frame)
    return Response(buffer.tobytes(), mimetype="image/jpeg")


@app.route("/health")
def health():
    return jsonify({"status": "ok", "images_loaded": len(stream_frames)})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, threaded=True)
