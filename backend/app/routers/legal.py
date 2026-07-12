from html import escape

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from ..config import get_settings


router = APIRouter(prefix="/legal", tags=["legal"])


def page(title: str, body: str) -> HTMLResponse:
    return HTMLResponse(
        f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{escape(title)} | Cardify</title>
  <style>
    :root {{ color-scheme: light; --ink: #17342f; --muted: #5f706b; --mint: #dff4eb; --line: #dce8e3; --paper: #fffdfa; }}
    * {{ box-sizing: border-box; }}
    body {{ margin: 0; background: #f3f7f4; color: var(--ink); font: 16px/1.75 -apple-system, BlinkMacSystemFont, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif; }}
    main {{ width: min(760px, calc(100% - 32px)); margin: 48px auto; padding: 40px; background: var(--paper); border: 1px solid var(--line); border-radius: 20px; box-shadow: 0 18px 50px rgba(27, 63, 52, .08); }}
    .brand {{ color: #159579; font-weight: 750; letter-spacing: .02em; }}
    h1 {{ margin: 10px 0 6px; font-size: 32px; line-height: 1.2; }}
    h2 {{ margin: 32px 0 8px; font-size: 20px; }}
    p, li {{ color: #334640; }}
    .updated {{ color: var(--muted); font-size: 14px; }}
    a {{ color: #087d67; }}
    footer {{ margin-top: 32px; padding-top: 18px; border-top: 1px solid var(--line); color: var(--muted); font-size: 14px; }}
    @media (max-width: 560px) {{ main {{ width: 100%; margin: 0; min-height: 100vh; padding: 28px 22px; border: 0; border-radius: 0; }} }}
  </style>
</head>
<body><main>{body}</main></body>
</html>"""
    )


def contact_line() -> str:
    email = escape(get_settings().legal_contact_email)
    return f'<p>如需联系 Cardify，请发送邮件至 <a href="mailto:{email}">{email}</a>。</p>'


@router.get("/privacy", response_class=HTMLResponse, include_in_schema=False)
def privacy_policy() -> HTMLResponse:
    content = f"""
<div class="brand">Cardify</div>
<h1>隐私政策</h1>
<p class="updated">最后更新：2026 年 7 月 12 日</p>
<p>Cardify 是一款用于创建、编辑和导出分享卡片的应用。本政策说明我们在提供这些功能时如何处理你的信息。</p>
<h2>我们处理的信息</h2>
<ul>
  <li>账户信息：通过“通过 Apple 登录”提供的应用专用账户标识，以及你主动提供的显示名称。</li>
  <li>创作内容：输入文本、卡片标题、版式参数、你选择上传的封面或头像图片，以及导出的作品文件。</li>
  <li>订阅状态：Apple 交易标识、产品标识和到期或撤销状态。付款信息由 Apple 处理，Cardify 不接触你的支付卡信息。</li>
</ul>
<h2>信息的用途</h2>
<p>我们仅将这些信息用于登录验证、跨设备同步作品、保存和导出卡片、核验会员权益、保障服务安全与处理必要的支持请求。Cardify 不投放广告，不出售个人信息，也不将信息用于跨应用追踪。</p>
<h2>存储与共享</h2>
<p>云端作品和必要的账户记录存储在 Cardify 的服务基础设施中；本机草稿保存在你的设备上。我们会与 Apple 交互以完成 Apple 登录和 App Store 订阅核验。除提供服务、遵守法律或保护用户与服务安全所必需的情形外，我们不会向第三方披露你的内容。</p>
<h2>保留与删除</h2>
<p>你可在 App 的“我的”页面发起删除账户。账户删除后，Cardify 会删除云端账户、作品、图片和会员记录；本机未同步草稿仍保留在设备上，可由你在作品库中自行删除。删除账户不会取消通过 Apple 购买的订阅，你需要在 Apple 账户的订阅管理中取消续费。</p>
<h2>你的选择</h2>
<p>你可以不登录而使用本机草稿功能，也可以在系统设置中管理照片权限。你可通过 App 内的账户删除功能清除云端数据。</p>
<h2>政策更新</h2>
<p>当服务或法律要求发生变化时，我们可能更新本政策，并在此页面更新日期。</p>
{contact_line()}
<footer><a href="/legal/terms">服务条款</a></footer>
"""
    return page("隐私政策", content)


@router.get("/terms", response_class=HTMLResponse, include_in_schema=False)
def terms_of_service() -> HTMLResponse:
    content = f"""
<div class="brand">Cardify</div>
<h1>服务条款</h1>
<p class="updated">最后更新：2026 年 7 月 12 日</p>
<p>欢迎使用 Cardify。使用本应用即表示你同意以下条款。</p>
<h2>服务内容</h2>
<p>Cardify 提供卡片创作、编辑、导出、作品同步及可选会员权益。部分功能需要网络连接或 Apple 账户登录。</p>
<h2>你的内容</h2>
<p>你保留对自己上传和创作内容的权利。你应确保拥有使用所上传素材的权利，并不得利用服务发布违法、侵权、欺诈或有害内容。</p>
<h2>订阅与付款</h2>
<p>Cardify 可能提供自动续期订阅。价格、周期和具体权益以 App Store 购买页面显示的信息为准。订阅会自动续期，除非你在当前订阅周期结束前至少 24 小时取消；Apple 会在当前周期结束前 24 小时内向你的 Apple 账户收取下一周期费用。你可以在 Apple 账户的订阅管理中管理或取消订阅。</p>
<p>删除 Cardify 账户不会取消你的 App Store 订阅或退款。退款申请请通过 Apple 的退款流程处理。</p>
<h2>账户与服务变更</h2>
<p>你有责任妥善使用你的 Apple 登录账户。我们可能为维护安全、合规和服务质量而更新、暂停或终止部分功能，并会在合理范围内提供通知。</p>
<h2>免责声明</h2>
<p>在法律允许的范围内，服务按“现状”和“可用”基础提供。对于因网络、设备、第三方服务或超出我们合理控制范围的原因造成的中断或数据损失，我们将在适用法律要求的范围内承担责任。</p>
<h2>条款更新</h2>
<p>我们可能更新这些条款，并在此页面更新日期。继续使用服务即表示你接受更新后的条款。</p>
{contact_line()}
<footer><a href="/legal/privacy">隐私政策</a></footer>
"""
    return page("服务条款", content)
