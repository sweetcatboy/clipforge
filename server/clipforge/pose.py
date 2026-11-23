"""Per-frame 3D body pose from a video with MediaPipe Pose Landmarker (Tasks API, legacy Solutions fallback)."""
from __future__ import annotations

import os
from typing import Callable

import numpy as np

from .config import MODEL_DIRS

MODEL_FILES = ["pose_landmarker_heavy.task", "pose_landmarker_full.task", "pose_landmarker_lite.task"]


def _model_path() -> str | None:
    for d in MODEL_DIRS:
        for name in MODEL_FILES:
            p = os.path.join(d, name)
            if os.path.exists(p):
                return p
    return None


def extract_pose(video_path: str, progress: Callable[[float, str], None] | None = None,
                 max_seconds: float = 60.0) -> dict:
    """Returns {"world": (T,33,3), "image": (T,33,3), "visibility": (T,33), "detected": (T,), "fps": float,
    "size": (w, h)}. World coordinates are MediaPipe's (metres, hip-centred, x right, y down, z away)."""
    import cv2

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Could not open the video: {video_path}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    if fps <= 1 or fps > 240:
        fps = 30.0
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 0)
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 0)
    limit = int(max_seconds * fps)
    if total <= 0:
        total = limit

    world, image, vis, det = [], [], [], []
    model = _model_path()
    detector = None
    legacy = None
    if model:
        import mediapipe as mp
        from mediapipe.tasks import python as mp_python
        from mediapipe.tasks.python import vision

        options = vision.PoseLandmarkerOptions(
            base_options=mp_python.BaseOptions(model_asset_path=model),
            running_mode=vision.RunningMode.VIDEO,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_pose_presence_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        detector = vision.PoseLandmarker.create_from_options(options)
    else:
        import mediapipe as mp
        if not hasattr(mp, "solutions"):
            raise RuntimeError("No pose model found. Run setup.ps1 to download pose_landmarker_heavy.task.")
        legacy = mp.solutions.pose.Pose(static_image_mode=False, model_complexity=2, smooth_landmarks=False,
                                        enable_segmentation=False, min_detection_confidence=0.5,
                                        min_tracking_confidence=0.5)

    i = 0
    try:
        while i < limit:
            ok, frame = cap.read()
            if not ok:
                break
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            wl = np.full((33, 3), np.nan)
            il = np.full((33, 3), np.nan)
            vv = np.zeros(33)
            found = False
            if detector is not None:
                import mediapipe as mp
                img = mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb))
                res = detector.detect_for_video(img, int(round(i * 1000.0 / fps)))
                if res.pose_world_landmarks:
                    found = True
                    for j, p in enumerate(res.pose_world_landmarks[0]):
                        wl[j] = (p.x, p.y, p.z)
                    for j, p in enumerate(res.pose_landmarks[0]):
                        il[j] = (p.x * w, p.y * h, p.z * w)
                        vv[j] = min(getattr(p, "visibility", 1.0) or 0.0, getattr(p, "presence", 1.0) or 1.0)
            else:
                res = legacy.process(rgb)
                if res.pose_world_landmarks:
                    found = True
                    for j, p in enumerate(res.pose_world_landmarks.landmark):
                        wl[j] = (p.x, p.y, p.z)
                    for j, p in enumerate(res.pose_landmarks.landmark):
                        il[j] = (p.x * w, p.y * h, p.z * w)
                        vv[j] = p.visibility
            world.append(wl)
            image.append(il)
            vis.append(vv)
            det.append(found)
            i += 1
            if progress and i % 10 == 0:
                progress(min(1.0, i / max(1, min(total, limit))), f"Tracking body pose ({i} frames)")
    finally:
        cap.release()
        if detector is not None:
            detector.close()
        if legacy is not None:
            legacy.close()

    if not world:
        raise RuntimeError("The video has no readable frames.")
    return {
        "world": np.array(world),
        "image": np.array(image),
        "visibility": np.array(vis),
        "detected": np.array(det, dtype=bool),
        "fps": float(fps),
        "size": (w, h),
    }
