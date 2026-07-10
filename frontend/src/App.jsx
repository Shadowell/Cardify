import { useMemo, useRef, useState } from "react";
import {
  BatteryFull,
  BookOpen,
  Briefcase,
  Cards,
  CaretLeft,
  CaretRight,
  Check,
  CheckCircle,
  ClipboardText,
  Crown,
  DownloadSimple,
  Export,
  FileArrowUp,
  FileText,
  House,
  ImageSquare,
  Images,
  LockKey,
  MagnifyingGlass,
  MagicWand,
  PaintBrush,
  Palette,
  PencilSimple,
  ShareNetwork,
  SlidersHorizontal,
  Sparkle,
  TextAa,
  Trash,
  UserCircle,
  WifiHigh,
  X,
} from "@phosphor-icons/react";
import brandLockup from "./assets/brand-lockup.png";
import cardForest from "./assets/card-forest.png";
import cardFreedom from "./assets/card-freedom.png";
import cardKnowledge from "./assets/card-knowledge.png";
import cardLife from "./assets/card-life.png";
import cardReading from "./assets/card-reading.png";
import cardStack from "./assets/card-stack.png";
import cardWork from "./assets/card-work.png";
import foldCorner from "./assets/fold-corner.png";

const sampleText =
  "真正的自由，不是想做什么，就做什么，而是不想做什么，就可以不做什么。";
const initialText = "";

const scenes = [
  {
    id: "knowledge",
    title: "知识卡",
    desc: "适合知识分享\n小红书、图文笔记",
    icon: FileText,
    tone: "rose",
  },
  {
    id: "life",
    title: "生活语录",
    desc: "适合情感表达\n朋友圈、日常分享",
    icon: Cards,
    tone: "sage",
  },
  {
    id: "career",
    title: "职场卡",
    desc: "适合观点表达\nLinkedIn、工作总结",
    icon: Briefcase,
    tone: "blue",
  },
  {
    id: "reading",
    title: "读书摘录",
    desc: "适合书摘记录\n读书笔记、书摘分享",
    icon: BookOpen,
    tone: "sand",
  },
];

const templates = [
  {
    id: "freedom",
    label: "雾",
    category: "知识",
    image: cardFreedom,
    theme: "rose",
  },
  {
    id: "knowledge",
    label: "第一",
    category: "知识卡",
    image: cardKnowledge,
    theme: "rose",
  },
  {
    id: "life",
    label: "海岸",
    category: "生活语录",
    image: cardLife,
    theme: "blue",
  },
  {
    id: "bookpage",
    label: "书页",
    category: "读书摘录",
    image: cardReading,
    theme: "paper",
  },
  {
    id: "work",
    label: "职场白",
    category: "职场卡",
    image: cardWork,
    theme: "white",
  },
  {
    id: "reading",
    label: "浅玫瑰",
    category: "读书摘录",
    image: cardReading,
    theme: "paper",
  },
];

const previewCards = {
  forest: {
    id: "forest",
    label: "墨绿",
    category: "知识",
    image: cardForest,
  },
  life: templates.find((template) => template.id === "life"),
};

const styleTabs = ["推荐", "知识", "语录", "职场", "书摘"];
const editTabs = ["样式", "字体", "颜色", "布局"];

function StatusBar() {
  return (
    <div className="status-bar" aria-label="status">
      <span>9:41</span>
      <span className="system-icons">
        <span className="signal-bars" aria-hidden="true">
          <i />
          <i />
          <i />
        </span>
        <WifiHigh size={14} weight="bold" />
        <BatteryFull size={18} weight="fill" />
      </span>
    </div>
  );
}

function Header({ title, subtitle, onBack, right, search }) {
  return (
    <header className="screen-header">
      <button
        className={`icon-button ${onBack ? "" : "invisible"}`}
        type="button"
        onClick={onBack}
        aria-label="返回"
      >
        <CaretLeft size={20} />
      </button>
      <div className="header-copy">
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </div>
      {right || (
        <button
          className={`icon-button ${search ? "" : "invisible"}`}
          type="button"
          aria-label="搜索"
        >
          <MagnifyingGlass size={19} />
        </button>
      )}
    </header>
  );
}

function PrimaryButton({ children, onClick, className = "", icon: Icon }) {
  return (
    <button className={`primary-button ${className}`} type="button" onClick={onClick}>
      <span>{children}</span>
      {Icon && <Icon size={17} weight="fill" />}
    </button>
  );
}

function TemplateImage({ template, className = "" }) {
  return (
    <img
      className={`template-image ${className}`}
      src={template.image}
      alt={`${template.category} ${template.label}`}
      draggable="false"
    />
  );
}

function HomeScreen({
  text,
  onTextChange,
  onGenerate,
  onPaste,
  onImport,
  onClear,
  onNavigate,
}) {
  return (
    <section className="screen home-screen">
      <div className="brand-zone">
        <img className="brand-lockup" src={brandLockup} alt="魔卡 Cardify" />
        <p>把文字，变成值得分享的精美卡片</p>
      </div>

      <div className="composer-card">
        <img className="fold-corner" src={foldCorner} alt="" aria-hidden="true" />
        <textarea
          value={text}
          onChange={(event) => onTextChange(event.target.value.slice(0, 5000))}
          placeholder="在这里粘贴你的文字&#10;&#10;支持 Markdown"
        />
        <span className="counter">{text.length} / 5000</span>
        <div className="composer-actions">
          <button type="button" onClick={onPaste}>
            <ClipboardText size={16} />
            粘贴
          </button>
          <button type="button" onClick={onImport}>
            <FileArrowUp size={16} />
            导入文件
          </button>
          <button type="button" onClick={onClear}>
            <Trash size={16} />
            清空
          </button>
        </div>
      </div>

      <PrimaryButton onClick={onGenerate} icon={Sparkle}>
        生成魔卡
      </PrimaryButton>

      <div className="magic-divider">
        <Sparkle size={12} weight="fill" />
        <span>文字变卡片的魔法</span>
        <Sparkle size={12} weight="fill" />
      </div>

      <div className="mini-preview">
        <TemplateImage template={templates[0]} />
        <CaretRight size={17} />
        <div className="mini-stack">
          {templates.slice(1, 4).map((template) => (
            <TemplateImage key={template.id} template={template} />
          ))}
        </div>
      </div>

      <BottomNav active="home" onNavigate={onNavigate} />
    </section>
  );
}

function BottomNav({ active, onNavigate }) {
  const items = [
    { id: "home", label: "首页", icon: House },
    { id: "works", label: "作品", icon: Images },
    { id: "styles", label: "风格", icon: Palette },
    { id: "profile", label: "我的", icon: UserCircle },
  ];

  return (
    <nav className="bottom-nav" aria-label="主导航">
      {items.map((item) => {
        const Icon = item.icon;
        return (
          <button
            key={item.id}
            className={active === item.id ? "active" : ""}
            type="button"
            onClick={() => onNavigate(item.id)}
          >
            <Icon size={20} weight={active === item.id ? "fill" : "regular"} />
            <span>{item.label}</span>
          </button>
        );
      })}
    </nav>
  );
}

function ScenarioScreen({ onBack, onChoose, recentTemplateId }) {
  return (
    <section className="screen scenario-screen">
      <Header title="选择发布场景" subtitle="为你的内容选择合适的卡片风格" onBack={onBack} />

      <div className="scene-grid">
        {scenes.map((scene) => {
          const Icon = scene.icon;
          return (
            <button
              key={scene.id}
              className={`scene-card tone-${scene.tone}`}
              type="button"
              onClick={() => onChoose(scene.id, "scene")}
            >
              <Icon size={28} weight="duotone" />
              <strong>{scene.title}</strong>
              <span>{scene.desc}</span>
            </button>
          );
        })}
      </div>

      <button className="hint-card" type="button" onClick={() => onChoose("knowledge", "scene")}>
        <span>之后也可以在生成预览页</span>
        <strong>
          随时切换风格
          <Sparkle size={14} weight="fill" />
        </strong>
      </button>

      <div className="recent-section">
        <div className="section-title">
          <span>最近使用</span>
          <button type="button">
            查看全部
            <CaretRight size={13} />
          </button>
        </div>
        <div className="recent-strip">
          {templates.map((template) => (
            <button
              key={template.id}
              className={template.id === recentTemplateId ? "selected" : ""}
              type="button"
              onClick={() => onChoose(template.id, "template")}
            >
              <TemplateImage template={template} />
            </button>
          ))}
        </div>
      </div>
    </section>
  );
}

function PreviewScreen({ selectedTemplate, onBack, onStyles, onEdit, onExport, onRatio }) {
  return (
    <section className="screen preview-screen">
      <Header title="生成预览" subtitle="已为你生成 3 张卡片" onBack={onBack} />

      <div className="preview-stage">
        <TemplateImage template={previewCards.forest} className="side-card left" />
        <TemplateImage template={previewCards.life} className="side-card right" />
        <TemplateImage template={selectedTemplate} className="hero-card" />
      </div>

      <div className="pager-dots" aria-label="预览分页">
        <span className="active" />
        <span />
        <span />
        <span />
        <span />
      </div>

      <div className="preview-toolbar">
        <button type="button" onClick={onStyles}>
          <PaintBrush size={23} />
          <span>换风格</span>
        </button>
        <button type="button" onClick={onRatio}>
          <Cards size={23} />
          <span>比例</span>
        </button>
        <button type="button" onClick={onEdit}>
          <PencilSimple size={23} />
          <span>编辑</span>
        </button>
        <button type="button" onClick={onExport}>
          <Export size={23} />
          <span>导出</span>
        </button>
      </div>
    </section>
  );
}

function StylesScreen({ selectedTemplateId, activeTab, onTab, onBack, onChoose }) {
  const visibleTemplates = useMemo(() => {
    if (activeTab === "推荐") return templates;
    return templates.filter((template) => template.category.includes(activeTab));
  }, [activeTab]);

  return (
    <section className="screen styles-screen">
      <Header title="选择风格" onBack={onBack} search />

      <div className="tab-row" role="tablist" aria-label="风格分类">
        {styleTabs.map((tab) => (
          <button
            key={tab}
            className={activeTab === tab ? "active" : ""}
            type="button"
            onClick={() => onTab(tab)}
          >
            {tab}
          </button>
        ))}
      </div>

      <div className="template-grid">
        {(visibleTemplates.length ? visibleTemplates : templates).map((template) => (
          <button
            key={template.id}
            className="style-card"
            type="button"
            onClick={() => onChoose(template.id)}
          >
            <TemplateImage template={template} />
            <span className="style-label">{template.label}</span>
            {template.id === selectedTemplateId && (
              <span className="chosen-badge">
                <Check size={13} weight="bold" />
                已选
              </span>
            )}
          </button>
        ))}
      </div>
    </section>
  );
}

function EditScreen({
  selectedTemplate,
  activeEditTab,
  onEditTab,
  fontSize,
  onFontSize,
  onBack,
  onDone,
}) {
  const optionRows = {
    样式: ["思源宋体", "思源黑体", "微蒙文楷"],
    字体: ["标题加粗", "正文舒展", "标点优化"],
    颜色: ["雾粉纸", "松石绿", "海岸蓝"],
    布局: ["标题居左", "留白加宽", "编号展示"],
  };

  return (
    <section className="screen edit-screen">
      <Header
        title="编辑卡片"
        onBack={onBack}
        right={
          <button className="done-link" type="button" onClick={onDone}>
            完成
          </button>
        }
      />

      <div className="edit-preview-card">
        <TemplateImage template={selectedTemplate} />
      </div>

      <div className="edit-panel">
        <div className="tab-row compact" role="tablist" aria-label="编辑分类">
          {editTabs.map((tab) => (
            <button
              key={tab}
              className={activeEditTab === tab ? "active" : ""}
              type="button"
              onClick={() => onEditTab(tab)}
            >
              {tab}
            </button>
          ))}
        </div>

        <div className="option-list">
          {optionRows[activeEditTab].map((label, index) => (
            <button key={label} type="button">
              <span>{label}</span>
              {index === 0 ? <Check size={16} /> : <CaretRight size={16} />}
            </button>
          ))}
        </div>

        <label className="slider-row">
          <span>字号</span>
          <strong>{fontSize}</strong>
          <input
            type="range"
            min="24"
            max="40"
            value={fontSize}
            style={{ "--range-progress": `${((fontSize - 24) / 16) * 100}%` }}
            onChange={(event) => onFontSize(Number(event.target.value))}
          />
          <span>A+</span>
        </label>
      </div>
    </section>
  );
}

function SuccessScreen({ onBackHome, onEditAgain, onShare, onPro }) {
  return (
    <section className="screen success-screen">
      <div className="success-confetti" aria-hidden="true">
        {Array.from({ length: 12 }).map((_, index) => (
          <span key={index} />
        ))}
      </div>
      <CheckCircle className="success-check" size={44} weight="fill" />
      <h1>已保存到相册</h1>
      <p>共 3 张卡片</p>

      <img className="success-stack" src={cardStack} alt="已导出的卡片组" />

      <PrimaryButton className="share-button" onClick={onShare} icon={ShareNetwork}>
        分享全部图片
      </PrimaryButton>

      <div className="action-list">
        <button type="button" onClick={onPro}>
          <DownloadSimple size={18} />
          <span>生成长图（拼接）</span>
          <CaretRight size={16} />
        </button>
        <button type="button" onClick={onEditAgain}>
          <PencilSimple size={18} />
          <span>再次编辑</span>
          <CaretRight size={16} />
        </button>
        <button type="button" onClick={onBackHome}>
          <House size={18} />
          <span>返回首页</span>
          <CaretRight size={16} />
        </button>
      </div>
    </section>
  );
}

function ProModal({ onClose }) {
  const perks = [
    { icon: LockKey, title: "无水印发布", desc: "让作品更专业" },
    { icon: ImageSquare, title: "高清导出", desc: "2K / 4K 高清图片" },
    { icon: Cards, title: "解锁高级模板", desc: "更多纸感风格" },
    { icon: Palette, title: "保存个人风格", desc: "一键复用配色字体" },
    { icon: TextAa, title: "自定义字号与品牌色", desc: "打造你的专属卡片" },
    { icon: SlidersHorizontal, title: "专属排版比例", desc: "适配多平台尺寸" },
  ];

  return (
    <div className="modal-backdrop" role="presentation">
      <section className="pro-modal" role="dialog" aria-modal="true" aria-label="解锁魔卡 Pro">
        <button className="modal-close" type="button" onClick={onClose} aria-label="关闭">
          <X size={18} />
        </button>
        <Crown className="pro-crown" size={25} weight="duotone" />
        <h2>解锁魔卡 Pro</h2>
        <p>让你的卡片，更专业，更自由</p>

        <div className="perk-grid">
          {perks.map((perk) => {
            const Icon = perk.icon;
            return (
              <div key={perk.title}>
                <Icon size={22} />
                <strong>{perk.title}</strong>
                <span>{perk.desc}</span>
              </div>
            );
          })}
        </div>

        <div className="price-row">
          <button type="button">
            <strong>¥18 / 月</strong>
            <span>7 天免费试用</span>
          </button>
          <button className="selected" type="button">
            <strong>¥88 / 年</strong>
            <span>限时权益</span>
          </button>
        </div>

        <PrimaryButton onClick={onClose} icon={Sparkle}>
          开始使用 Pro
        </PrimaryButton>
        <small>恢复购买 · 使用条款 · 隐私政策</small>
      </section>
    </div>
  );
}

function Toast({ message }) {
  if (!message) return null;
  return <div className="toast">{message}</div>;
}

export function App() {
  const [screen, setScreen] = useState("home");
  const [text, setText] = useState(initialText);
  const [selectedTemplateId, setSelectedTemplateId] = useState("freedom");
  const [activeStyleTab, setActiveStyleTab] = useState("推荐");
  const [activeEditTab, setActiveEditTab] = useState("样式");
  const [fontSize, setFontSize] = useState(32);
  const [toast, setToast] = useState("");
  const [proOpen, setProOpen] = useState(false);
  const fileInputRef = useRef(null);

  const selectedTemplate =
    templates.find((template) => template.id === selectedTemplateId) || templates[0];

  function flash(message) {
    setToast(message);
    window.clearTimeout(flash.timer);
    flash.timer = window.setTimeout(() => setToast(""), 1900);
  }

  async function handlePaste() {
    try {
      const clipText = await navigator.clipboard.readText();
      setText(clipText || sampleText);
      flash("已粘贴到输入框");
    } catch {
      setText(sampleText);
      flash("已填入示例文案");
    }
  }

  function handleImportClick() {
    fileInputRef.current?.click();
  }

  function handleImportFile(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      setText(String(reader.result || "").slice(0, 5000));
      flash("文件内容已导入");
    };
    reader.readAsText(file);
    event.target.value = "";
  }

  function handleNav(item) {
    if (item === "home") setScreen("home");
    if (item === "works") setScreen("preview");
    if (item === "styles") setScreen("styles");
    if (item === "profile") setProOpen(true);
  }

  function handleChooseScene(sceneOrTemplateId, source = "scene") {
    const matchingTemplate = templates.find((template) => template.id === sceneOrTemplateId);
    if (source === "template" && matchingTemplate) setSelectedTemplateId(matchingTemplate.id);
    setScreen("preview");
  }

  function handleChooseStyle(templateId) {
    setSelectedTemplateId(templateId);
    setScreen("edit");
    flash("已套用新风格");
  }

  return (
    <main className="app-shell">
      <input
        ref={fileInputRef}
        className="visually-hidden"
        type="file"
        accept=".txt,.md,.markdown"
        onChange={handleImportFile}
      />
      <div className="phone-frame">
        <StatusBar />
        {screen === "home" && (
          <HomeScreen
            text={text}
            onTextChange={setText}
            onGenerate={() => setScreen("scenario")}
            onPaste={handlePaste}
            onImport={handleImportClick}
            onClear={() => {
              setText("");
              flash("输入已清空");
            }}
            onNavigate={handleNav}
          />
        )}
        {screen === "scenario" && (
          <ScenarioScreen
            onBack={() => setScreen("home")}
            onChoose={handleChooseScene}
            recentTemplateId={selectedTemplateId}
          />
        )}
        {screen === "preview" && (
          <PreviewScreen
            selectedTemplate={selectedTemplate}
            onBack={() => setScreen("scenario")}
            onStyles={() => setScreen("styles")}
            onEdit={() => setScreen("edit")}
            onExport={() => setScreen("success")}
            onRatio={() => flash("比例已切换为 4:5")}
          />
        )}
        {screen === "styles" && (
          <StylesScreen
            selectedTemplateId={selectedTemplateId}
            activeTab={activeStyleTab}
            onTab={setActiveStyleTab}
            onBack={() => setScreen("preview")}
            onChoose={handleChooseStyle}
          />
        )}
        {screen === "edit" && (
          <EditScreen
            selectedTemplate={selectedTemplate}
            activeEditTab={activeEditTab}
            onEditTab={setActiveEditTab}
            fontSize={fontSize}
            onFontSize={setFontSize}
            onBack={() => setScreen("preview")}
            onDone={() => setScreen("success")}
          />
        )}
        {screen === "success" && (
          <SuccessScreen
            onBackHome={() => setScreen("home")}
            onEditAgain={() => setScreen("edit")}
            onShare={() => flash("已唤起分享面板")}
            onPro={() => setProOpen(true)}
          />
        )}
        {proOpen && <ProModal onClose={() => setProOpen(false)} />}
        <Toast message={toast} />
      </div>
    </main>
  );
}
