import base64
from datetime import datetime, timedelta, timezone


def test_templates_are_seeded(client):
    response = client.get("/templates")
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) >= 6
    assert {"知识卡", "育儿", "营销", "视频卡", "旅行", "探店", "分享卡"}.issubset({item["category"] for item in items})

    detail = client.get(f"/templates/{items[0]['id']}")
    assert detail.status_code == 200
    assert detail.json()["schema"]["canvas_sizes"][0]["id"] == "xhs-3-4"


def test_generation_lifecycle(client):
    response = client.post("/generations", json={"input_text": "孩子英语启蒙，从兴趣和日常对话开始。"})
    assert response.status_code == 202
    task_id = response.json()["id"]

    detail = client.get(f"/generations/{task_id}")
    assert detail.status_code == 200
    payload = detail.json()
    assert payload["status"] == "succeeded"
    assert payload["output"]["tags"][0] == "#育儿经验"


def test_work_save_and_local_export(client, authenticated_session):
    work_response = client.post(
        "/works",
        json={
            "template_id": "parenting-note",
            "title": "启蒙记录",
            "input_text": "孩子每天 15 分钟英文儿歌输入。",
            "render_params": {"canvas_size_id": "xhs-3-4"},
        },
        headers=authenticated_session["headers"],
    )
    assert work_response.status_code == 201
    work_id = work_response.json()["id"]

    image_payload = base64.b64encode(b"fake-png-bytes").decode("ascii")
    export_response = client.post(
        f"/works/{work_id}/export",
        json={"filename": "card.png", "image_base64": image_payload},
        headers=authenticated_session["headers"],
    )
    assert export_response.status_code == 200
    assert export_response.json()["export_path"].endswith("/card.png")


def test_export_rejects_unsafe_extension(client, authenticated_session):
    work_response = client.post(
        "/works",
        json={
            "template_id": "knowledge-note",
            "title": "知识卡",
            "input_text": "一段知识内容。",
            "render_params": {},
        },
        headers=authenticated_session["headers"],
    )
    work_id = work_response.json()["id"]
    image_payload = base64.b64encode(b"fake").decode("ascii")

    response = client.post(
        f"/works/{work_id}/export",
        json={"filename": "../bad.svg", "image_base64": image_payload},
        headers=authenticated_session["headers"],
    )
    assert response.status_code == 400


def test_work_update_list_and_delete(client, authenticated_session):
    created = client.post(
        "/works",
        json={
            "template_id": "knowledge-note",
            "title": "第一版",
            "input_text": "一段知识内容。",
            "render_params": {"canvas_size_id": "xhs-3-4"},
        },
        headers=authenticated_session["headers"],
    )
    assert created.status_code == 201
    work_id = created.json()["id"]

    updated = client.patch(
        f"/works/{work_id}",
        json={
            "template_id": "knowledge-note",
            "title": "编辑后的标题",
            "input_text": "编辑后的内容。",
            "render_params": {"canvas_size_id": "square-1-1", "card_content": {"theme": "sky"}},
        },
        headers=authenticated_session["headers"],
    )
    assert updated.status_code == 200
    assert updated.json()["title"] == "编辑后的标题"

    listed = client.get("/works", headers=authenticated_session["headers"])
    assert listed.status_code == 200
    assert any(item["id"] == work_id for item in listed.json()["items"])

    deleted = client.delete(f"/works/{work_id}", headers=authenticated_session["headers"])
    assert deleted.status_code == 200
    assert deleted.json()["deleted"] == work_id


def test_auth_session_and_subscription_stub(client, authenticated_session):
    user_id = authenticated_session["user_id"]

    expires_at = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()
    subscription_response = client.post(
        "/subscriptions/verify",
        json={
            "user_id": user_id,
            "product_id": "cardify.pro.monthly",
            "transaction_id": "tx-local-1",
            "expires_at": expires_at,
        },
    )
    assert subscription_response.status_code == 200
    assert subscription_response.json()["status"] == "active"


def test_work_endpoints_require_an_authenticated_session(client):
    response = client.get("/works")
    assert response.status_code == 401
