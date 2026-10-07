import json
import threading
import urllib.error
import urllib.request

import pytest

from app.server import make_server


@pytest.fixture(scope="module")
def base_url():
    server = make_server(0)  # port 0 -> OS picks a free port
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield f"http://127.0.0.1:{port}"
    server.shutdown()


def get(url):
    try:
        with urllib.request.urlopen(url) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def test_health(base_url):
    status, body = get(base_url + "/health")
    assert status == 200 and body["status"] == "ok"


def test_add(base_url):
    status, body = get(base_url + "/calc?op=add&a=10&b=5")
    assert status == 200 and body["result"] == 15


def test_divide_by_zero_is_400(base_url):
    status, body = get(base_url + "/calc?op=divide&a=1&b=0")
    assert status == 400 and "zero" in body["error"].lower()


def test_unknown_op(base_url):
    status, _ = get(base_url + "/calc?op=pow&a=1&b=2")
    assert status == 400


def test_not_found(base_url):
    status, _ = get(base_url + "/nope")
    assert status == 404
