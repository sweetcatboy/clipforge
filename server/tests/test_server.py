"""The HTTP layer: every request gets an answer (bad numbers are a 400, never a dropped connection or a hang),
cross-site requests are refused, words preview without a job. Runs a server on a free port with a throwaway data
folder. Run:  python tests/test_server.py"""
import json
import os
import sys
import tempfile
import threading
import urllib.error
import urllib.request

os.environ["CLIPFORGE_DATA"] = tempfile.mkdtemp(prefix="clipforge-test-")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from clipforge import server  # noqa: E402
from clipforge.jobs import JobStore  # noqa: E402

HTTPD = server.make_server("127.0.0.1", 0, JobStore())
threading.Thread(target=HTTPD.serve_forever, daemon=True).start()
BASE = f"http://127.0.0.1:{HTTPD.server_address[1]}"


def call(method, path, body=None, headers=None, raw=None):
    h = {"Content-Type": "application/json", **(headers or {})}
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(BASE + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "null")


def test_bad_numbers_are_400():
    st, job = call("POST", "/api/jobs", {"prompt": "wave", "kind": "animation"})
    assert st == 201, (st, job)
    for path in ("/api/jobs?limit=abc", "/api/jobs?since=x", f"/api/jobs/{job['id']}?wait=abc",
                 f"/api/jobs/{job['id']}?wait=nan", f"/api/jobs/{job['id']}?wait=inf"):
        st, body = call("GET", path)
        assert st == 400 and "number" in body["error"], (path, st, body)
    st, body = call("GET", "/api/jobs?limit=-5&since=-1")
    assert st == 200 and body["jobs"], (st, body)


def test_origin_and_preview():
    st, body = call("POST", "/api/jobs", {"prompt": "jab"}, headers={"Origin": "https://example.com"})
    assert st == 403, (st, body)
    before = len(call("GET", "/api/jobs?limit=1000")[1]["jobs"])
    st, body = call("POST", "/api/preview", {"prompt": "fire punch"})
    assert st == 200 and body["plan"]["animation"] and body["plan"]["vfx"], (st, body)
    assert len(call("GET", "/api/jobs?limit=1000")[1]["jobs"]) == before
    st, body = call("POST", "/api/preview", {"prompt": "asdfghjkl"})
    assert st == 400 and "Nothing to make" in body["error"], (st, body)
    st, body = call("POST", "/api/jobs", raw=b"{oops")
    assert st == 400, (st, body)


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("ok", name)
    HTTPD.shutdown()
    print("all server tests passed")
