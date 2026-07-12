import base64
from datetime import datetime, timedelta, timezone

from app.routers.subscriptions import get_storekit_transaction_verifier
from app.services.storekit import VerifiedStoreKitTransaction
from app.main import app


def test_templates_are_seeded(client):
    response = client.get("/templates")
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 20
    assert len({item["id"] for item in items}) == 20
    assert [item["id"] for item in items[:3]] == ["note-share-poster", "local-store", "travel-guide"]
    assert {"知识卡", "育儿", "营销", "视频卡", "旅行", "探店", "分享卡", "生活"}.issubset(
        {item["category"] for item in items}
    )

    for item in items:
        schema = item["schema"]
        assert schema["default_canvas_size_id"] in {size["id"] for size in schema["canvas_sizes"]}
        assert any(layer["role"] == "title" for layer in schema["layers"])
        assert any(layer["role"] == "decorative_pattern" for layer in schema["layers"])
        assert schema["tokens"]["palette"]["paper"].startswith("#")
        for layer in schema["layers"]:
            frame = layer["frame"]
            assert frame["x"] + frame["width"] <= 1
            assert frame["y"] + frame["height"] <= 1

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

    asset_response = client.post(
        f"/works/{work_id}/assets",
        json={
            "kind": "cover",
            "filename": "cover.jpg",
            "image_base64": image_payload,
        },
        headers=authenticated_session["headers"],
    )
    assert asset_response.status_code == 200
    asset_path = asset_response.json()["render_params"]["assets"]["cover"]
    assert asset_path.endswith("/asset-cover-cover.jpg")
    assert client.get(f"/storage/{asset_path}").status_code == 404

    asset_read = client.get(f"/works/{work_id}/assets/cover", headers=authenticated_session["headers"])
    assert asset_read.status_code == 200
    assert asset_read.content == b"fake-png-bytes"

    update_response = client.patch(
        f"/works/{work_id}",
        json={
            "template_id": "parenting-note",
            "title": "启蒙记录更新",
            "input_text": "孩子每天 15 分钟英文儿歌输入。",
            "render_params": {"canvas_size_id": "xhs-3-4"},
        },
        headers=authenticated_session["headers"],
    )
    assert update_response.status_code == 200
    assert update_response.json()["render_params"]["assets"]["cover"].endswith("/asset-cover-cover.jpg")

    asset_delete = client.delete(f"/works/{work_id}/assets/cover", headers=authenticated_session["headers"])
    assert asset_delete.status_code == 200
    assert client.get(f"/works/{work_id}/assets/cover", headers=authenticated_session["headers"]).status_code == 404


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
    assert listed.json()["total"] >= 1

    deleted = client.delete(f"/works/{work_id}", headers=authenticated_session["headers"])
    assert deleted.status_code == 200
    assert deleted.json()["deleted"] == work_id


def test_work_list_filters_and_pagination(client, authenticated_session):
    headers = authenticated_session["headers"]
    for index, payload in enumerate(
        [
            {"template_id": "knowledge-note", "title": "知识笔记", "input_text": "一段知识内容。"},
            {"template_id": "parenting-note", "title": "育儿笔记", "input_text": "孩子的成长记录。"},
            {"template_id": "knowledge-note", "title": "知识复盘", "input_text": "另一段知识内容。"},
        ]
    ):
        created = client.post(
            "/works",
            json={**payload, "render_params": {"canvas_size_id": "xhs-3-4"}},
            headers=headers,
        )
        assert created.status_code == 201
        if index == 0:
            exported = client.post(
                f"/works/{created.json()['id']}/export",
                json={"filename": "card.png", "image_base64": base64.b64encode(b"preview").decode("ascii")},
                headers=headers,
            )
            assert exported.status_code == 200

    filtered = client.get(
        "/works",
        params={"query": "知识", "template_id": "knowledge-note", "page": 1, "page_size": 1},
        headers=headers,
    )
    assert filtered.status_code == 200
    assert filtered.json()["total"] == 2
    assert len(filtered.json()["items"]) == 1
    assert filtered.json()["page"] == 1
    assert filtered.json()["page_size"] == 1

    exported = client.get("/works", params={"exported": "true"}, headers=headers)
    assert exported.status_code == 200
    assert exported.json()["total"] == 1

    pending_export = client.get("/works", params={"exported": "false"}, headers=headers)
    assert pending_export.status_code == 200
    assert pending_export.json()["total"] == 2


class StubStoreKitTransactionVerifier:
    def __init__(self, transaction: VerifiedStoreKitTransaction):
        self.transaction = transaction

    def verify(self, signed_transaction_info: str) -> VerifiedStoreKitTransaction:
        assert signed_transaction_info == "signed-apple-transaction-token-123456789"
        return self.transaction


def test_subscription_verification_requires_a_signed_apple_transaction(client, authenticated_session):
    user_id = authenticated_session["user_id"]
    expires_at = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()
    transaction = VerifiedStoreKitTransaction(
        transaction_id="tx-local-1",
        product_id="com.jiefeng.cardify.pro.monthly",
        app_account_token=user_id,
        expires_at=datetime.fromisoformat(expires_at),
        revoked_at=None,
    )
    app.dependency_overrides[get_storekit_transaction_verifier] = lambda: StubStoreKitTransactionVerifier(transaction)
    try:
        subscription_response = client.post(
            "/subscriptions/verify",
            json={"signed_transaction_info": "signed-apple-transaction-token-123456789"},
            headers=authenticated_session["headers"],
        )
        assert subscription_response.status_code == 200, subscription_response.text
        assert subscription_response.json()["status"] == "active"
        assert subscription_response.json()["is_pro"] is True

        status_response = client.get("/subscriptions/me", headers=authenticated_session["headers"])
        assert status_response.status_code == 200
        assert status_response.json()["product_id"] == "com.jiefeng.cardify.pro.monthly"
    finally:
        app.dependency_overrides.pop(get_storekit_transaction_verifier, None)


def test_subscription_rejects_a_transaction_bound_to_another_user(client, authenticated_session):
    transaction = VerifiedStoreKitTransaction(
        transaction_id="tx-other-account",
        product_id="com.jiefeng.cardify.pro.monthly",
        app_account_token="00000000-0000-0000-0000-000000000001",
        expires_at=datetime.now(timezone.utc) + timedelta(days=30),
        revoked_at=None,
    )
    app.dependency_overrides[get_storekit_transaction_verifier] = lambda: StubStoreKitTransactionVerifier(transaction)
    try:
        response = client.post(
            "/subscriptions/verify",
            json={"signed_transaction_info": "signed-apple-transaction-token-123456789"},
            headers=authenticated_session["headers"],
        )
        assert response.status_code == 403, response.text
    finally:
        app.dependency_overrides.pop(get_storekit_transaction_verifier, None)


def test_work_endpoints_require_an_authenticated_session(client):
    response = client.get("/works")
    assert response.status_code == 401


def test_account_deletion_removes_cloud_data_and_invalidates_session(client, authenticated_session, tmp_path):
    headers = authenticated_session["headers"]
    user_id = authenticated_session["user_id"]
    image_payload = base64.b64encode(b"account-owned-image").decode("ascii")
    created = client.post(
        "/works",
        json={
            "template_id": "knowledge-note",
            "title": "待删除的作品",
            "input_text": "账户删除测试内容。",
            "render_params": {},
        },
        headers=headers,
    )
    assert created.status_code == 201
    work_id = created.json()["id"]
    assert client.post(
        f"/works/{work_id}/export",
        json={"filename": "account.png", "image_base64": image_payload},
        headers=headers,
    ).status_code == 200
    assert client.post(
        f"/works/{work_id}/assets",
        json={"kind": "cover", "filename": "cover.jpg", "image_base64": image_payload},
        headers=headers,
    ).status_code == 200

    deleted = client.delete("/auth/me", headers=headers)
    assert deleted.status_code == 200
    assert deleted.json() == {"deleted": user_id}
    assert client.get("/works", headers=headers).status_code == 401
    assert not (tmp_path / "storage" / f"works-{work_id}").exists()


def test_legal_pages_are_public(client):
    privacy = client.get("/legal/privacy")
    terms = client.get("/legal/terms")

    assert privacy.status_code == 200
    assert "隐私政策" in privacy.text
    assert terms.status_code == 200
    assert "服务条款" in terms.text
